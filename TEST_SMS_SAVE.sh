#!/bin/bash

echo "🧪 Test SMS Template Save Directly"
echo "===================================="
echo ""

cat << 'VPSCMD'
cd /var/www/school
source venv/bin/activate

# Test saving a template directly
python3 << 'EOF'
from app import create_app
from models import db, Settings, User

app = create_app('production')

with app.app_context():
    print("Testing template save...")
    
    # Get a teacher user
    teacher = User.query.filter_by(role='TEACHER').first()
    if not teacher:
        teacher = User.query.first()
    
    print(f"Using user: {teacher.id if teacher else 'None'}")
    
    # Create a test template
    template_key = "sms_template_custom_exam"
    test_message = "Test: {student_name} got {marks}/{total}"
    
    # Check if exists
    existing = Settings.query.filter_by(key=template_key).first()
    
    if existing:
        print(f"Found existing template: {existing.key}")
        existing.value = {'message': test_message}
        existing.updated_by = teacher.id if teacher else 1
    else:
        print("Creating new template...")
        new_template = Settings(
            key=template_key,
            value={'message': test_message},
            description="Test SMS template",
            category="sms_templates",
            updated_by=teacher.id if teacher else 1
        )
        db.session.add(new_template)
    
    db.session.commit()
    print("✅ Template saved!")
    
    # Verify it was saved
    saved = Settings.query.filter_by(key=template_key).first()
    if saved:
        print(f"✅ Verified: {saved.key} = {saved.value.get('message')}")
    else:
        print("❌ Template not found after save!")
    
    # List all templates
    all_templates = Settings.query.filter(Settings.key.like('sms_template_%')).all()
    print(f"\n📊 Total SMS templates in DB: {len(all_templates)}")
    for t in all_templates:
        print(f"  - {t.key}")

EOF

deactivate

echo ""
echo "Now restart and check if template persists:"
echo "sudo systemctl restart saro.service"

VPSCMD
