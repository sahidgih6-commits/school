"""
telegram_bot.py
===============
Modern Ideal School – Telegram Bot
Reads & updates student attendance directly from the school database.

Bot: t.me/Modernidealschool_bot

Commands (Teacher / Admin):
  /start           – Welcome & help
  /today           – Today's attendance summary for all batches
  /report <date>   – Attendance report for a specific date (YYYY-MM-DD)
  /batch <id>      – List students & today's status for a batch
  /batches         – List all active batches
  /mark <student_code> <present|absent|leave> [date]  – Mark/update one record
  /bulkmark <batch_id> <present|absent> [date]         – Mark all in a batch
  /student <code>  – Student profile + last 7-day attendance
  /students [batch_id] – List students (optionally filtered by batch)
  /absent <date>   – List absent students for a date
  /stats           – Monthly attendance stats for today's month

Commands (Student):
  /mystatus        – Your own last 30-day attendance
  /myreport [month] [year] – Monthly attendance summary

Run:
  python telegram_bot.py          (polling – development)
  python telegram_bot.py webhook  (webhook – production)
"""

import os
import sys
import logging
from datetime import datetime, date, timedelta
from functools import wraps

from dotenv import load_dotenv
load_dotenv()

# ── Telegram imports (python-telegram-bot v20+) ──────────────────────────────
from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup, BotCommand
)
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    ContextTypes, MessageHandler, filters
)
from telegram.constants import ParseMode

# ── Flask app context for DB access ──────────────────────────────────────────
sys.path.insert(0, os.path.dirname(__file__))
from app import create_app
from models import db, User, Batch, Attendance, UserRole, AttendanceStatus

flask_app = create_app()

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s – %(message)s",
    handlers=[
        logging.FileHandler("telegram_bot.log", encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger(__name__)

# ── Config ────────────────────────────────────────────────────────────────────
BOT_TOKEN  = os.environ.get("TELEGRAM_BOT_TOKEN", "")
WEBHOOK_URL = os.environ.get("TELEGRAM_WEBHOOK_URL", "")   # e.g. https://yourdomain.com/tgwebhook
WEBHOOK_PORT = int(os.environ.get("TELEGRAM_WEBHOOK_PORT", "8443"))

# Optional: restrict commands to these Telegram chat IDs (leave empty = anyone)
ALLOWED_CHAT_IDS: list[int] = [
    int(x) for x in os.environ.get("TELEGRAM_ALLOWED_IDS", "").split(",") if x.strip()
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def restricted(func):
    """Decorator: only allow listed chat IDs (if ALLOWED_CHAT_IDS is set)."""
    @wraps(func)
    async def wrapper(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
        if ALLOWED_CHAT_IDS and update.effective_chat.id not in ALLOWED_CHAT_IDS:
            await update.message.reply_text("⛔ You are not authorised to use this bot.")
            return
        return await func(update, ctx)
    return wrapper


def _status_icon(status: AttendanceStatus) -> str:
    icons = {
        AttendanceStatus.PRESENT: "✅",
        AttendanceStatus.ABSENT:  "❌",
        AttendanceStatus.LEAVE:   "🟡",
    }
    return icons.get(status, "❓")


def _parse_date(s: str) -> date | None:
    for fmt in ("%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            pass
    return None


def _get_or_create_attendance(user_id: int, batch_id: int,
                               att_date: date, status: AttendanceStatus,
                               marked_by_id: int | None = None) -> tuple[Attendance, bool]:
    """Upsert an attendance record. Returns (record, created)."""
    record = Attendance.query.filter_by(
        user_id=user_id, batch_id=batch_id, date=att_date
    ).first()
    created = False
    if record is None:
        record = Attendance(
            user_id=user_id,
            batch_id=batch_id,
            date=att_date,
            status=status,
            marked_by=marked_by_id,
        )
        db.session.add(record)
        created = True
    else:
        record.status = status
        record.updated_at = datetime.utcnow()
    db.session.commit()
    return record, created


# ── /start ────────────────────────────────────────────────────────────────────
@restricted
async def cmd_start(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    text = (
        "🏫 <b>Modern Ideal School Bot</b>\n\n"
        "I can read &amp; update student attendance from the school system.\n\n"
        "<b>Teacher / Admin commands:</b>\n"
        "• /today – today's attendance summary\n"
        "• /report YYYY-MM-DD – report for a date\n"
        "• /absent YYYY-MM-DD – absent list\n"
        "• /batch &lt;id&gt; – batch details &amp; attendance\n"
        "• /batches – all active batches\n"
        "• /students [batch_id] – student list\n"
        "• /student &lt;code&gt; – student profile\n"
        "• /mark &lt;code&gt; &lt;present|absent|leave&gt; [date]\n"
        "• /bulkmark &lt;batch_id&gt; &lt;status&gt; [date]\n"
        "• /stats – this month's stats\n\n"
        "<b>Student commands:</b>\n"
        "• /link &lt;student_code&gt; – link your account\n"
        "• /mystatus – your last 30 days\n"
        "• /myreport [month] [year]\n\n"
        "📅 Default date is always <b>today</b>."
    )
    await update.message.reply_text(text, parse_mode=ParseMode.HTML)


# ── /batches ──────────────────────────────────────────────────────────────────
@restricted
async def cmd_batches(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    with flask_app.app_context():
        batches = Batch.query.filter_by(is_active=True, is_archived=False).order_by(Batch.name).all()
        if not batches:
            await update.message.reply_text("No active batches found.")
            return

        lines = ["📚 <b>Active Batches</b>\n"]
        for b in batches:
            count = len([s for s in b.students if s.is_active and not s.is_archived])
            lines.append(f"• <code>{b.id}</code> – <b>{b.name}</b> ({count} students)")
        lines.append("\nUse /batch &lt;id&gt; to see details.")
        await update.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)


# ── /batch <id> ───────────────────────────────────────────────────────────────
@restricted
async def cmd_batch(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not ctx.args:
        await update.message.reply_text("Usage: /batch <batch_id>")
        return

    try:
        batch_id = int(ctx.args[0])
    except ValueError:
        await update.message.reply_text("❌ batch_id must be a number.")
        return

    target_date = date.today()
    with flask_app.app_context():
        batch = Batch.query.get(batch_id)
        if not batch:
            await update.message.reply_text(f"❌ Batch {batch_id} not found.")
            return

        students = [s for s in batch.students if s.is_active and not s.is_archived]
        att_map = {
            a.user_id: a.status
            for a in Attendance.query.filter_by(batch_id=batch_id, date=target_date).all()
        }

        lines = [f"📋 *{batch.name}* – {target_date.strftime('%d %b %Y')}\n"]
        present = absent = leave = unmarked = 0
        for s in sorted(students, key=lambda x: x.full_name):
            status = att_map.get(s.id)
            if status is None:
                icon = "⬜"; unmarked += 1
            else:
                icon = _status_icon(status)
                if status == AttendanceStatus.PRESENT: present += 1
                elif status == AttendanceStatus.ABSENT: absent += 1
                else: leave += 1
            code = s.student_code or str(s.id)
            lines.append(f"{icon} `{code}` {s.full_name}")

        lines.append(
            f"\n✅ {present}  ❌ {absent}  🟡 {leave}  ⬜ {unmarked} unmarked"
        )
        # Send in chunks if too long
        text = "\n".join(lines)
        await _send_long(update, text)


# ── /today ────────────────────────────────────────────────────────────────────
@restricted
async def cmd_today(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    await _attendance_report(update, date.today())


# ── /report <date> ────────────────────────────────────────────────────────────
@restricted
async def cmd_report(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not ctx.args:
        await update.message.reply_text("Usage: /report YYYY-MM-DD")
        return
    d = _parse_date(ctx.args[0])
    if not d:
        await update.message.reply_text("❌ Invalid date. Use YYYY-MM-DD")
        return
    await _attendance_report(update, d)


async def _attendance_report(update: Update, report_date: date):
    with flask_app.app_context():
        batches = Batch.query.filter_by(is_active=True, is_archived=False).all()
        if not batches:
            await update.message.reply_text("No active batches.")
            return

        lines = [f"📊 *Attendance Report – {report_date.strftime('%d %b %Y')}*\n"]
        grand_present = grand_absent = grand_leave = grand_students = 0

        for batch in sorted(batches, key=lambda b: b.name):
            students = [s for s in batch.students if s.is_active and not s.is_archived]
            if not students:
                continue
            att_map = {
                a.user_id: a.status
                for a in Attendance.query.filter_by(batch_id=batch.id, date=report_date).all()
            }
            present = sum(1 for s in students if att_map.get(s.id) == AttendanceStatus.PRESENT)
            absent  = sum(1 for s in students if att_map.get(s.id) == AttendanceStatus.ABSENT)
            leave   = sum(1 for s in students if att_map.get(s.id) == AttendanceStatus.LEAVE)
            total   = len(students)
            pct     = round(present / total * 100) if total else 0

            grand_present += present; grand_absent += absent
            grand_leave   += leave;   grand_students += total

            lines.append(
                f"*{batch.name}*\n"
                f"  ✅ {present}  ❌ {absent}  🟡 {leave}  / {total} → {pct}%"
            )

        if grand_students:
            g_pct = round(grand_present / grand_students * 100)
            lines.append(
                f"\n*TOTAL:* ✅ {grand_present}  ❌ {grand_absent}  "
                f"🟡 {grand_leave}  / {grand_students} → *{g_pct}%*"
            )
        await _send_long(update, "\n".join(lines))


# ── /absent <date> ────────────────────────────────────────────────────────────
@restricted
async def cmd_absent(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    d = date.today()
    if ctx.args:
        d = _parse_date(ctx.args[0]) or date.today()

    with flask_app.app_context():
        records = (
            Attendance.query
            .filter_by(date=d, status=AttendanceStatus.ABSENT)
            .join(User).join(Batch)
            .order_by(Batch.name, User.first_name)
            .all()
        )
        if not records:
            await update.message.reply_text(
                f"✅ No absent students on {d.strftime('%d %b %Y')}."
            )
            return

        lines = [f"❌ *Absent on {d.strftime('%d %b %Y')}*\n"]
        current_batch = None
        for r in records:
            if r.batch.name != current_batch:
                current_batch = r.batch.name
                lines.append(f"\n*{current_batch}*")
            code = r.user.student_code or str(r.user_id)
            lines.append(f"  • `{code}` {r.user.full_name}")
        await _send_long(update, "\n".join(lines))


# ── /students [batch_id] ──────────────────────────────────────────────────────
@restricted
async def cmd_students(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    with flask_app.app_context():
        if ctx.args:
            try:
                batch_id = int(ctx.args[0])
                batch = Batch.query.get(batch_id)
                if not batch:
                    await update.message.reply_text(f"❌ Batch {batch_id} not found.")
                    return
                students = [s for s in batch.students if s.is_active and not s.is_archived]
                header = f"👥 *Students in {batch.name}*\n"
            except ValueError:
                await update.message.reply_text("Usage: /students [batch_id]")
                return
        else:
            students = User.query.filter_by(
                role=UserRole.STUDENT, is_active=True, is_archived=False
            ).order_by(User.first_name).all()
            header = f"👥 *All Students* ({len(students)} total)\n"

        if not students:
            await update.message.reply_text("No students found.")
            return

        lines = [header]
        for s in sorted(students, key=lambda x: x.full_name):
            code = s.student_code or str(s.id)
            lines.append(f"• `{code}` {s.full_name}")
        await _send_long(update, "\n".join(lines))


# ── /student <code> ───────────────────────────────────────────────────────────
@restricted
async def cmd_student(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not ctx.args:
        await update.message.reply_text("Usage: /student <student_code>")
        return

    code = ctx.args[0]
    with flask_app.app_context():
        student = User.query.filter_by(student_code=code, is_archived=False).first()
        if not student:
            # Try by ID
            try:
                student = User.query.filter_by(id=int(code), is_archived=False).first()
            except ValueError:
                pass
        if not student:
            await update.message.reply_text(f"❌ Student `{code}` not found.")
            return

        batches_str = ", ".join(b.name for b in student.batches if b.is_active) or "None"
        lines = [
            f"👤 *{student.full_name}*",
            f"Code: `{student.student_code or 'N/A'}`",
            f"Phone: `{student.phoneNumber}`",
            f"Guardian: {student.guardian_name or 'N/A'}",
            f"Batches: {batches_str}",
            "",
            f"*Last 7 days attendance:*"
        ]

        today = date.today()
        for i in range(6, -1, -1):
            d = today - timedelta(days=i)
            records = Attendance.query.filter_by(user_id=student.id, date=d).all()
            if records:
                icons = " ".join(_status_icon(r.status) for r in records)
                lines.append(f"  {d.strftime('%d %b')} – {icons}")
            else:
                lines.append(f"  {d.strftime('%d %b')} – ⬜")

        await _send_long(update, "\n".join(lines))


# ── /mark <code> <status> [date] ─────────────────────────────────────────────
@restricted
async def cmd_mark(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if len(ctx.args) < 2:
        await update.message.reply_text(
            "Usage: /mark <student_code> <present|absent|leave> [YYYY-MM-DD]"
        )
        return

    code   = ctx.args[0]
    status_str = ctx.args[1].lower()
    target_date = _parse_date(ctx.args[2]) if len(ctx.args) > 2 else date.today()

    status_map = {
        "present": AttendanceStatus.PRESENT,
        "absent":  AttendanceStatus.ABSENT,
        "leave":   AttendanceStatus.LEAVE,
        "p": AttendanceStatus.PRESENT,
        "a": AttendanceStatus.ABSENT,
        "l": AttendanceStatus.LEAVE,
    }
    if status_str not in status_map:
        await update.message.reply_text("❌ Status must be: present, absent, or leave")
        return

    att_status = status_map[status_str]

    with flask_app.app_context():
        student = User.query.filter_by(student_code=code, is_archived=False).first()
        if not student:
            try:
                student = User.query.filter_by(id=int(code), is_archived=False).first()
            except ValueError:
                pass
        if not student:
            await update.message.reply_text(f"❌ Student `{code}` not found.")
            return

        active_batches = [b for b in student.batches if b.is_active]
        if not active_batches:
            await update.message.reply_text(f"❌ {student.full_name} has no active batch.")
            return

        results = []
        for batch in active_batches:
            _, created = _get_or_create_attendance(
                student.id, batch.id, target_date, att_status
            )
            action = "Created" if created else "Updated"
            results.append(f"  {action} – {batch.name}")

        icon = _status_icon(att_status)
        lines = [
            f"{icon} *{student.full_name}* marked *{status_str}* on {target_date.strftime('%d %b %Y')}:"
        ] + results
        await update.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)


# ── /bulkmark <batch_id> <status> [date] ─────────────────────────────────────
@restricted
async def cmd_bulkmark(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if len(ctx.args) < 2:
        await update.message.reply_text(
            "Usage: /bulkmark <batch_id> <present|absent|leave> [YYYY-MM-DD]"
        )
        return

    try:
        batch_id = int(ctx.args[0])
    except ValueError:
        await update.message.reply_text("❌ batch_id must be a number.")
        return

    status_str  = ctx.args[1].lower()
    target_date = _parse_date(ctx.args[2]) if len(ctx.args) > 2 else date.today()

    status_map = {
        "present": AttendanceStatus.PRESENT,
        "absent":  AttendanceStatus.ABSENT,
        "leave":   AttendanceStatus.LEAVE,
    }
    if status_str not in status_map:
        await update.message.reply_text("❌ Status must be: present, absent, or leave")
        return

    att_status = status_map[status_str]

    with flask_app.app_context():
        batch = Batch.query.get(batch_id)
        if not batch:
            await update.message.reply_text(f"❌ Batch {batch_id} not found.")
            return

        students = [s for s in batch.students if s.is_active and not s.is_archived]
        if not students:
            await update.message.reply_text("No active students in this batch.")
            return

        created_count = updated_count = 0
        for s in students:
            _, created = _get_or_create_attendance(s.id, batch_id, target_date, att_status)
            if created:
                created_count += 1
            else:
                updated_count += 1

        icon = _status_icon(att_status)
        await update.message.reply_text(
            f"{icon} *Bulk Mark – {batch.name}*\n"
            f"Date: {target_date.strftime('%d %b %Y')}\n"
            f"Status: *{status_str}*\n"
            f"✅ Created: {created_count}  🔄 Updated: {updated_count}\n"
            f"Total: {len(students)} students",
            parse_mode=ParseMode.HTML,
        )


# ── /stats  ───────────────────────────────────────────────────────────────────
@restricted
async def cmd_stats(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    today = date.today()
    month = int(ctx.args[0]) if ctx.args else today.month
    year  = int(ctx.args[1]) if len(ctx.args) > 1 else today.year

    with flask_app.app_context():
        from sqlalchemy import extract
        records = (
            Attendance.query
            .filter(
                extract('month', Attendance.date) == month,
                extract('year',  Attendance.date) == year,
            )
            .all()
        )

        total    = len(records)
        present  = sum(1 for r in records if r.status == AttendanceStatus.PRESENT)
        absent   = sum(1 for r in records if r.status == AttendanceStatus.ABSENT)
        leave    = sum(1 for r in records if r.status == AttendanceStatus.LEAVE)
        pct      = round(present / total * 100) if total else 0

        month_name = datetime(year, month, 1).strftime("%B %Y")
        text = (
            f"📈 *Monthly Stats – {month_name}*\n\n"
            f"✅ Present : {present}\n"
            f"❌ Absent  : {absent}\n"
            f"🟡 Leave   : {leave}\n"
            f"📌 Total   : {total}\n"
            f"📊 Rate    : *{pct}%*"
        )
        await update.message.reply_text(text, parse_mode=ParseMode.HTML)


# ── /mystatus  ────────────────────────────────────────────────────────────────
@restricted
async def cmd_mystatus(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    """Student checks their own attendance via their student_code stored in context."""
    # Students must link their account first via /link <student_code>
    user_data = ctx.user_data
    student_code = user_data.get("student_code")
    if not student_code:
        await update.message.reply_text(
            "Please link your account first:\n/link <your_student_code>"
        )
        return

    with flask_app.app_context():
        student = User.query.filter_by(student_code=student_code, is_archived=False).first()
        if not student:
            await update.message.reply_text("❌ Linked student not found. Use /link again.")
            return

        today = date.today()
        lines = [f"📅 *Your last 30 days – {student.full_name}*\n"]
        for i in range(29, -1, -1):
            d = today - timedelta(days=i)
            records = Attendance.query.filter_by(user_id=student.id, date=d).all()
            if records:
                icons = " ".join(_status_icon(r.status) for r in records)
                lines.append(f"  {d.strftime('%d %b')} – {icons}")
        await _send_long(update, "\n".join(lines))


# ── /link <student_code> ─────────────────────────────────────────────────────
@restricted
async def cmd_link(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    """Students link their Telegram account to their student code."""
    if not ctx.args:
        await update.message.reply_text("Usage: /link <student_code>")
        return
    code = ctx.args[0]
    with flask_app.app_context():
        student = User.query.filter_by(
            student_code=code, is_archived=False, role=UserRole.STUDENT
        ).first()
        if not student:
            await update.message.reply_text(f"❌ Student code `{code}` not found.")
            return
        ctx.user_data["student_code"] = code
        await update.message.reply_text(
            f"✅ Linked to *{student.full_name}*\n"
            f"Now use /mystatus to see your attendance.",
            parse_mode=ParseMode.HTML,
        )


# ── /myreport [month] [year] ─────────────────────────────────────────────────
@restricted
async def cmd_myreport(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    user_data = ctx.user_data
    student_code = user_data.get("student_code")
    if not student_code:
        await update.message.reply_text("Please /link your account first.")
        return

    today = date.today()
    month = int(ctx.args[0]) if ctx.args else today.month
    year  = int(ctx.args[1]) if len(ctx.args) > 1 else today.year

    with flask_app.app_context():
        from sqlalchemy import extract
        student = User.query.filter_by(student_code=student_code).first()
        if not student:
            await update.message.reply_text("❌ Student not found.")
            return
        records = (
            Attendance.query
            .filter(
                Attendance.user_id == student.id,
                extract('month', Attendance.date) == month,
                extract('year',  Attendance.date) == year,
            )
            .all()
        )
        present = sum(1 for r in records if r.status == AttendanceStatus.PRESENT)
        absent  = sum(1 for r in records if r.status == AttendanceStatus.ABSENT)
        leave   = sum(1 for r in records if r.status == AttendanceStatus.LEAVE)
        total   = len(records)
        pct     = round(present / total * 100) if total else 0
        month_name = datetime(year, month, 1).strftime("%B %Y")
        text = (
            f"📊 *{student.full_name} – {month_name}*\n\n"
            f"✅ Present : {present}\n"
            f"❌ Absent  : {absent}\n"
            f"🟡 Leave   : {leave}\n"
            f"📌 Total   : {total}\n"
            f"📊 Rate    : *{pct}%*"
        )
        await update.message.reply_text(text, parse_mode=ParseMode.HTML)


# ── Unknown command ───────────────────────────────────────────────────────────
async def cmd_unknown(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "❓ Unknown command. Type /start to see all available commands."
    )


# ── Long message helper ───────────────────────────────────────────────────────
async def _send_long(update: Update, text: str, chunk_size: int = 4000):
    """Send a message, splitting into chunks if needed. Uses HTML parse mode."""
    # Convert markdown-like syntax to HTML for reliable rendering
    import html
    # We build plain text and send as HTML with <b> for *bold* and <code> for `mono`
    import re
    safe = html.escape(text)
    safe = re.sub(r'\*([^*]+)\*', r'<b>\1</b>', safe)
    safe = re.sub(r'`([^`]+)`', r'<code>\1</code>', safe)

    chunks = [safe[i:i+chunk_size] for i in range(0, len(safe), chunk_size)]
    for chunk in chunks:
        await update.message.reply_text(chunk, parse_mode=ParseMode.HTML)


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    if not BOT_TOKEN:
        sys.exit("❌ TELEGRAM_BOT_TOKEN is not set in .env or environment.")

    app = Application.builder().token(BOT_TOKEN).build()

    # Register commands
    app.add_handler(CommandHandler("start",     cmd_start))
    app.add_handler(CommandHandler("help",      cmd_start))
    app.add_handler(CommandHandler("batches",   cmd_batches))
    app.add_handler(CommandHandler("batch",     cmd_batch))
    app.add_handler(CommandHandler("today",     cmd_today))
    app.add_handler(CommandHandler("report",    cmd_report))
    app.add_handler(CommandHandler("absent",    cmd_absent))
    app.add_handler(CommandHandler("students",  cmd_students))
    app.add_handler(CommandHandler("student",   cmd_student))
    app.add_handler(CommandHandler("mark",      cmd_mark))
    app.add_handler(CommandHandler("bulkmark",  cmd_bulkmark))
    app.add_handler(CommandHandler("stats",     cmd_stats))
    app.add_handler(CommandHandler("mystatus",  cmd_mystatus))
    app.add_handler(CommandHandler("myreport",  cmd_myreport))
    app.add_handler(CommandHandler("link",      cmd_link))
    app.add_handler(MessageHandler(filters.COMMAND, cmd_unknown))

    mode = sys.argv[1] if len(sys.argv) > 1 else "polling"

    if mode == "webhook":
        if not WEBHOOK_URL:
            sys.exit("❌ TELEGRAM_WEBHOOK_URL is not set.")
        log.info(f"Starting webhook on port {WEBHOOK_PORT}: {WEBHOOK_URL}/tgwebhook")
        app.run_webhook(
            listen="0.0.0.0",
            port=WEBHOOK_PORT,
            url_path="tgwebhook",
            webhook_url=f"{WEBHOOK_URL}/tgwebhook",
        )
    else:
        log.info("Starting polling mode…")
        app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
