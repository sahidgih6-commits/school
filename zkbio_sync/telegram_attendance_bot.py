"""
telegram_attendance_bot.py
==========================
A Telegram bot that runs on your Windows PC.
It reads today's attendance from ZKBio's SQLite database
and syncs it to the school app automatically or on command.

SETUP (Windows):
  pip install pyTelegramBotAPI requests schedule

HOW TO GET A BOT TOKEN:
  1. Open Telegram → search @BotFather
  2. Send /newbot → follow steps → copy the token
  3. Send /start to your new bot to get your Chat ID
     OR use @userinfobot to get your Telegram ID

USAGE:
  python telegram_attendance_bot.py

BOT COMMANDS:
  /sync          - Sync today's attendance right now
  /sync 2026-03-03  - Sync a specific date
  /status        - Show today's punch summary from ZKBio
  /students      - List student code ↔ name mapping
  /help          - Show help

Place this file next to zkbio_config.json
"""

import sqlite3, json, requests, schedule, time, logging, sys
from datetime import datetime, date, timedelta
from pathlib import Path

try:
    import telebot
except ImportError:
    sys.exit("Run:  pip install pyTelegramBotAPI")

# ── Logging ─────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
    handlers=[
        logging.FileHandler('telegram_bot.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout),
    ]
)
log = logging.getLogger(__name__)

CONFIG_FILE = Path(__file__).parent / 'zkbio_config.json'
DB_PATH     = r"C:\Program Files (x86)\ZKBio Time.Net\TimeNet.db"


def load_config() -> dict:
    if not CONFIG_FILE.exists():
        sys.exit(f'Config not found: {CONFIG_FILE}')
    with open(CONFIG_FILE, encoding='utf-8') as f:
        return json.load(f)


# ── ZKBio SQLite reader ───────────────────────────────────────────────────────

# ZKBio TimeNet.db table names (found by inspection)
# Try these tables in order
ZKBIO_TABLES = [
    ('att_attlog',    'emp_code', 'punch_time', 'punch_state'),
    ('att_attrecord', 'emp_code', 'att_date',   'punch_state'),
    ('iclock_transaction', 'emp_code', 'punch_time', 'punch_state'),
]

def get_zkbio_db_path(cfg: dict) -> str:
    return cfg.get('zkbio_db', {}).get('path', DB_PATH)


def read_zkbio_punches(cfg: dict, sync_date: date) -> list:
    db_path = get_zkbio_db_path(cfg)
    if not Path(db_path).exists():
        raise FileNotFoundError(f'ZKBio DB not found: {db_path}')

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur  = conn.cursor()

    # Get all table names first
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    existing_tables = {r['name'].lower() for r in cur.fetchall()}

    rows = []
    date_str = sync_date.strftime('%Y-%m-%d')

    for (tbl, emp_col, time_col, state_col) in ZKBIO_TABLES:
        if tbl.lower() not in existing_tables:
            continue
        try:
            cur.execute(f"""
                SELECT {emp_col} as emp_code,
                       {time_col} as punch_time,
                       {state_col} as punch_state
                FROM   {tbl}
                WHERE  DATE({time_col}) = ?
                ORDER  BY {emp_col}, {time_col}
            """, (date_str,))
            rows = [dict(r) for r in cur.fetchall()]
            log.info(f'Table {tbl}: {len(rows)} rows for {date_str}')
            break
        except Exception as e:
            log.warning(f'Table {tbl} failed: {e}')
            continue

    conn.close()

    # Aggregate per employee
    emp = {}
    for r in rows:
        code  = str(r['emp_code']).strip()
        ptime = r['punch_time']
        state = int(r.get('punch_state') or 0)
        if isinstance(ptime, str):
            try:    ptime = datetime.strptime(ptime, '%Y-%m-%d %H:%M:%S')
            except: ptime = datetime.strptime(ptime[:16], '%Y-%m-%d %H:%M')

        if code not in emp:
            emp[code] = {'check_in': None, 'check_out': None, 'all': []}
        emp[code]['all'].append(ptime)
        if state in (0, 4):
            if emp[code]['check_in'] is None or ptime < emp[code]['check_in']:
                emp[code]['check_in'] = ptime
        elif state in (1, 5):
            if emp[code]['check_out'] is None or ptime > emp[code]['check_out']:
                emp[code]['check_out'] = ptime

    result = []
    for code, d in emp.items():
        ci = d['check_in'] or (d['all'][0] if d['all'] else None)
        co = d['check_out']
        result.append({
            'emp_code':  code,
            'check_in':  ci.strftime('%H:%M') if ci else None,
            'check_out': co.strftime('%H:%M') if co else None,
        })
    return result


def get_employee_names(cfg: dict) -> dict:
    """Return {emp_code: name} from ZKBio hr_employee table"""
    db_path = get_zkbio_db_path(cfg)
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cur  = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = {r['name'].lower() for r in cur.fetchall()}

        for tbl in ('hr_employee', 'personnel_employee', 'iclock_terminal'):
            if tbl not in tables:
                continue
            try:
                cur.execute(f"SELECT emp_code, first_name||' '||last_name as name FROM {tbl}")
                result = {str(r['emp_code']): r['name'] for r in cur.fetchall()}
                conn.close()
                return result
            except:
                pass
        conn.close()
    except Exception as e:
        log.warning(f'Could not read employee names: {e}')
    return {}


def build_records(punches: list, mapping: dict, sync_date: date, late_after='09:00') -> list:
    punched = {p['emp_code'] for p in punches}
    records = []
    for p in punches:
        sid = mapping.get(p['emp_code'])
        if not sid:
            continue
        status = 'late' if (p['check_in'] and p['check_in'] > late_after) else 'present'
        records.append({
            'student_id': int(sid),
            'date':       sync_date.strftime('%Y-%m-%d'),
            'status':     status,
            'check_in':   p['check_in'],
            'check_out':  p['check_out'],
        })
    for code, sid in mapping.items():
        if code not in punched:
            records.append({'student_id': int(sid), 'date': sync_date.strftime('%Y-%m-%d'), 'status': 'absent'})
    return records


def push_to_school(cfg: dict, records: list) -> dict:
    sc  = cfg['school_app']
    url = sc['url'].rstrip('/') + '/api/attendance/biometric-sync'
    r   = requests.post(url, json={
        'api_key':  sc['api_key'],
        'batch_id': sc.get('batch_id'),
        'records':  records,
    }, timeout=30)
    if r.status_code == 200:
        return r.json().get('message', {})
    raise Exception(f'HTTP {r.status_code}: {r.text[:200]}')


def do_sync(cfg: dict, sync_date: date) -> str:
    """Core sync logic — returns a status message string"""
    try:
        mapping = cfg.get('student_mapping', {})
        if not mapping:
            return '⚠️ student_mapping is empty in zkbio_config.json\nAdd employee→student_id mapping first.'

        punches = read_zkbio_punches(cfg, sync_date)
        records = build_records(punches, mapping, sync_date, cfg.get('late_after','09:00'))

        if not records:
            return f'📭 No punch data found for {sync_date}'

        result = push_to_school(cfg, records)
        present = sum(1 for r in records if r['status'] in ('present','late'))
        absent  = sum(1 for r in records if r['status'] == 'absent')
        late    = sum(1 for r in records if r['status'] == 'late')

        return (f'✅ Sync done for {sync_date}\n'
                f'📊 Created: {result.get("created",0)}  '
                f'Updated: {result.get("updated",0)}\n'
                f'🟢 Present: {present}  🔴 Absent: {absent}  🕐 Late: {late}')
    except Exception as e:
        return f'❌ Sync failed: {e}'


# ── Telegram Bot ─────────────────────────────────────────────────────────────

def main():
    cfg = load_config()
    bot_token = cfg.get('telegram_bot_token')
    allowed_chat_id = cfg.get('telegram_chat_id')  # optional: restrict to one user

    if not bot_token:
        print('\n❌  telegram_bot_token not set in zkbio_config.json')
        print('    Get a token from @BotFather on Telegram, then add:')
        print('    "telegram_bot_token": "YOUR_TOKEN_HERE"')
        print('    "telegram_chat_id":   YOUR_NUMERIC_CHAT_ID')
        sys.exit(1)

    bot = telebot.TeleBot(bot_token)

    def is_allowed(msg) -> bool:
        if not allowed_chat_id:
            return True
        return str(msg.chat.id) == str(allowed_chat_id)

    @bot.message_handler(commands=['start', 'help'])
    def cmd_help(msg):
        if not is_allowed(msg): return
        bot.reply_to(msg,
            '📚 *Attendance Bot*\n\n'
            '/sync — Sync today\'s attendance from ZKBio\n'
            '/sync 2026-03-03 — Sync a specific date\n'
            '/status — Show today\'s punch list from ZKBio\n'
            '/students — List employee→student mapping\n'
            '/help — Show this message\n\n'
            f'Your chat ID: `{msg.chat.id}`',
            parse_mode='Markdown'
        )

    @bot.message_handler(commands=['sync'])
    def cmd_sync(msg):
        if not is_allowed(msg): return
        parts = msg.text.strip().split()
        if len(parts) > 1:
            try:
                sync_date = datetime.strptime(parts[1], '%Y-%m-%d').date()
            except ValueError:
                bot.reply_to(msg, '❌ Date format must be YYYY-MM-DD')
                return
        else:
            sync_date = date.today()

        bot.reply_to(msg, f'⏳ Syncing attendance for {sync_date}...')
        result = do_sync(cfg, sync_date)
        bot.send_message(msg.chat.id, result)

    @bot.message_handler(commands=['status'])
    def cmd_status(msg):
        if not is_allowed(msg): return
        today = date.today()
        try:
            punches = read_zkbio_punches(cfg, today)
            names   = get_employee_names(cfg)
            if not punches:
                bot.reply_to(msg, f'📭 No punches found for {today}')
                return
            lines = [f'📋 *Punches for {today}* ({len(punches)} employees)\n']
            for p in sorted(punches, key=lambda x: x.get('check_in') or ''):
                name = names.get(p['emp_code'], 'Unknown')
                ci   = p['check_in']  or '—'
                co   = p['check_out'] or '—'
                lines.append(f'`{p["emp_code"]}` {name}: IN {ci} | OUT {co}')
            bot.reply_to(msg, '\n'.join(lines), parse_mode='Markdown')
        except Exception as e:
            bot.reply_to(msg, f'❌ Error: {e}')

    @bot.message_handler(commands=['students'])
    def cmd_students(msg):
        if not is_allowed(msg): return
        mapping = cfg.get('student_mapping', {})
        if not mapping:
            bot.reply_to(msg, '⚠️ No student_mapping in zkbio_config.json')
            return
        lines = ['*Employee → Student mapping*']
        for code, sid in mapping.items():
            lines.append(f'`{code}` → student_id {sid}')
        bot.reply_to(msg, '\n'.join(lines), parse_mode='Markdown')

    # ── Auto-sync at 11 PM daily ─────────────────────────────────────────────
    def auto_sync():
        if allowed_chat_id:
            result = do_sync(cfg, date.today())
            bot.send_message(allowed_chat_id, f'🕙 *Auto-sync 11 PM*\n{result}', parse_mode='Markdown')
            log.info(f'Auto-sync: {result}')
        else:
            log.info('Auto-sync: no telegram_chat_id set, skipping notification')
            do_sync(cfg, date.today())

    schedule.every().day.at('23:00').do(auto_sync)

    print('✅ Telegram Attendance Bot is running...')
    print(f'   Auto-sync scheduled at 11:00 PM daily')
    print('   Send /help to your bot on Telegram')
    print('   Press Ctrl+C to stop')

    # Run scheduler + bot polling together
    import threading
    def run_scheduler():
        while True:
            schedule.run_pending()
            time.sleep(30)

    t = threading.Thread(target=run_scheduler, daemon=True)
    t.start()

    bot.infinity_polling()


if __name__ == '__main__':
    main()
