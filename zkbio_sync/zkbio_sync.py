"""
zkbio_sync.py
=============
Reads attendance punch records from ZKBio Time.Net's MySQL database and
pushes them to the school app's biometric-sync API.

Run on Windows (where ZKBio Time.Net is installed):
    python zkbio_sync.py              # sync today
    python zkbio_sync.py 2026-02-28  # sync specific date

Requirements (install once):
    pip install mysql-connector-python requests
"""

import sys
import json
import logging
from datetime import datetime, date, timedelta
from pathlib import Path

# ── Third-party (pip install mysql-connector-python requests) ──────────────
try:
    import mysql.connector
except ImportError:
    sys.exit("ERROR: Run:  pip install mysql-connector-python")

try:
    import requests
except ImportError:
    sys.exit("ERROR: Run:  pip install requests")

# ── Setup logging ─────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s  %(levelname)s  %(message)s',
    handlers=[
        logging.FileHandler('zkbio_sync.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout),
    ]
)
log = logging.getLogger(__name__)

CONFIG_FILE = Path(__file__).parent / 'zkbio_config.json'


def load_config() -> dict:
    if not CONFIG_FILE.exists():
        log.error(f'Config file not found: {CONFIG_FILE}')
        log.error('Copy zkbio_config.example.json to zkbio_config.json and fill it in.')
        sys.exit(1)
    with open(CONFIG_FILE, encoding='utf-8') as f:
        return json.load(f)


def get_zkbio_punches(cfg: dict, sync_date: date) -> list[dict]:
    """
    Query ZKBio Time.Net MySQL for all punch records on sync_date.

    ZKBio tables used:
      att_attlog          – raw punch events
        emp_code          – employee code (string, e.g. "001")
        punch_time        – DATETIME of punch
        punch_state       – 0=check_in, 1=check_out, 4=OT_in, 5=OT_out

    Returns list of:
      { 'emp_code': str, 'check_in': 'HH:MM', 'check_out': 'HH:MM' or None }
    """
    db_cfg = cfg['zkbio_mysql']
    conn = mysql.connector.connect(
        host     = db_cfg.get('host', '127.0.0.1'),
        port     = int(db_cfg.get('port', 3306)),
        user     = db_cfg['user'],
        password = db_cfg['password'],
        database = db_cfg.get('database', 'att'),
    )
    cur = conn.cursor(dictionary=True)

    # Pull all punches for the date, ordered by time
    cur.execute("""
        SELECT emp_code, punch_time, punch_state
        FROM att_attlog
        WHERE DATE(punch_time) = %s
        ORDER BY emp_code, punch_time
    """, (sync_date.strftime('%Y-%m-%d'),))

    rows = cur.fetchall()
    cur.close()
    conn.close()

    # Aggregate: per employee → earliest in-punch, latest out-punch
    emp_data: dict[str, dict] = {}
    for r in rows:
        code  = str(r['emp_code']).strip()
        ptime = r['punch_time']          # already a datetime object
        state = int(r['punch_state'])

        if code not in emp_data:
            emp_data[code] = {'check_in': None, 'check_out': None, 'raw_times': []}

        emp_data[code]['raw_times'].append(ptime)

        if state in (0, 4):  # in-types → take earliest
            if emp_data[code]['check_in'] is None or ptime < emp_data[code]['check_in']:
                emp_data[code]['check_in'] = ptime
        elif state in (1, 5):  # out-types → take latest
            if emp_data[code]['check_out'] is None or ptime > emp_data[code]['check_out']:
                emp_data[code]['check_out'] = ptime

    result = []
    for code, d in emp_data.items():
        # If only one punch (no state discrimination), use it as check-in only
        ci = d['check_in'] or (d['raw_times'][0] if d['raw_times'] else None)
        co = d['check_out']
        result.append({
            'emp_code':  code,
            'check_in':  ci.strftime('%H:%M') if ci else None,
            'check_out': co.strftime('%H:%M') if co else None,
        })

    log.info(f'ZKBio: {len(rows)} punch events → {len(result)} employees')
    return result


def build_records(punches: list[dict], mapping: dict, sync_date: date,
                  late_after: str = '09:00') -> list[dict]:
    """
    Convert ZKBio punches → school app attendance records.

    mapping = { "emp_code": student_id, ... }  (from zkbio_config.json)
    late_after   = HH:MM threshold – if check_in > this, mark late (still 'present')
    """
    punched_codes = {p['emp_code'] for p in punches}
    records = []

    # Students who punched → present / late
    for p in punches:
        sid = mapping.get(p['emp_code'])
        if not sid:
            log.warning(f'No mapping for emp_code={p["emp_code"]} – skipping')
            continue

        ci = p['check_in']
        status = 'present'
        if ci and ci > late_after:
            status = 'late'

        records.append({
            'student_id': int(sid),
            'date':       sync_date.strftime('%Y-%m-%d'),
            'status':     status,
            'check_in':   ci,
            'check_out':  p['check_out'],
        })

    # Students in mapping who did NOT punch → absent
    for emp_code, sid in mapping.items():
        if emp_code not in punched_codes:
            records.append({
                'student_id': int(sid),
                'date':       sync_date.strftime('%Y-%m-%d'),
                'status':     'absent',
            })

    return records


def push_to_school_app(cfg: dict, records: list[dict]) -> None:
    """POST records to the school app's biometric-sync endpoint."""
    school_cfg = cfg['school_app']
    url = school_cfg['url'].rstrip('/') + '/api/attendance/biometric-sync'

    payload = {
        'api_key':  school_cfg['api_key'],
        'batch_id': school_cfg.get('batch_id'),   # optional
        'records':  records,
    }

    log.info(f'Sending {len(records)} records → {url}')
    resp = requests.post(url, json=payload, timeout=30)

    if resp.status_code == 200:
        body = resp.json()
        d = body.get('data', {})
        log.info(f'✅  created={d.get("created")}  updated={d.get("updated")}  '
                 f'skipped={d.get("skipped")}')
        if d.get('errors'):
            for e in d['errors']:
                log.warning(f'Server: {e}')
    else:
        log.error(f'❌  HTTP {resp.status_code}: {resp.text[:300]}')


def main():
    cfg = load_config()

    # Date to sync (default = today)
    if len(sys.argv) > 1:
        try:
            sync_date = datetime.strptime(sys.argv[1], '%Y-%m-%d').date()
        except ValueError:
            sys.exit('Date must be YYYY-MM-DD')
    else:
        sync_date = date.today()

    log.info(f'━━━ ZKBio → School App sync for {sync_date} ━━━')

    punches = get_zkbio_punches(cfg, sync_date)
    mapping = cfg.get('student_mapping', {})   # { "001": 5, "002": 8, ... }
    late_after = cfg.get('late_after', '09:00')

    records = build_records(punches, mapping, sync_date, late_after)
    if not records:
        log.info('No records to send.')
        return

    push_to_school_app(cfg, records)


if __name__ == '__main__':
    main()
