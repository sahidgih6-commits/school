#!/usr/bin/env python3
"""
Check student batch enrollment and session data
"""
import sys
sys.path.insert(0, '/var/www/school')

from app import app
from models import db, User, UserRole, Batch

with app.app_context():
    print("=" * 60)
    print("STUDENT BATCH ENROLLMENT CHECK")
    print("=" * 60)
    
    # Find students with multiple batch enrollments
    students = User.query.filter_by(role=UserRole.STUDENT, is_active=True).all()
    
    multi_batch_students = []
    for student in students:
        if len(student.batches) > 1:
            multi_batch_students.append(student)
    
    print(f"\n📊 Total active students: {len(students)}")
    print(f"🎓 Students with multiple batches: {len(multi_batch_students)}")
    
    if multi_batch_students:
        print("\n" + "=" * 60)
        print("MULTI-BATCH STUDENTS")
        print("=" * 60)
        
        for student in multi_batch_students:
            print(f"\n👤 {student.first_name} {student.last_name}")
            print(f"   Phone: {student.phoneNumber}")
            print(f"   Batches:")
            for batch in student.batches:
                print(f"     - {batch.name} (ID: {batch.id})")
    
    # Check for students with same phone (siblings)
    print("\n" + "=" * 60)
    print("CHECKING FOR SIBLINGS (SAME PHONE)")
    print("=" * 60)
    
    from sqlalchemy import func
    phone_groups = db.session.query(
        User.phoneNumber,
        func.count(User.id).label('count')
    ).filter(
        User.role == UserRole.STUDENT,
        User.is_active == True
    ).group_by(User.phoneNumber).having(func.count(User.id) > 1).all()
    
    if phone_groups:
        print(f"\n👨‍👩‍👧‍👦 Found {len(phone_groups)} phone numbers with multiple students")
        
        for phone, count in phone_groups:
            print(f"\n📱 Phone: {phone} ({count} students)")
            siblings = User.query.filter_by(
                phoneNumber=phone,
                role=UserRole.STUDENT,
                is_active=True
            ).all()
            
            for sibling in siblings:
                print(f"   - {sibling.first_name} {sibling.last_name}")
                if sibling.batches:
                    batch_names = [b.name for b in sibling.batches]
                    print(f"     Batches: {', '.join(batch_names)}")
                else:
                    print(f"     Batches: None")
    else:
        print("\n✅ No siblings found (all students have unique phone numbers)")
    
    # Simulate login session for multi-batch/sibling students
    print("\n" + "=" * 60)
    print("SIMULATING LOGIN SESSION DATA")
    print("=" * 60)
    
    test_phones = []
    if phone_groups:
        test_phones.append(phone_groups[0][0])  # First sibling group
    if multi_batch_students:
        test_phones.append(multi_batch_students[0].phoneNumber)  # First multi-batch student
    
    for test_phone in set(test_phones):
        print(f"\n📱 Testing login with phone: {test_phone}")
        users = User.query.filter_by(
            phoneNumber=test_phone,
            role=UserRole.STUDENT,
            is_active=True
        ).all()
        
        print(f"   Found {len(users)} student(s) with this phone")
        
        # Simulate session data collection
        all_batch_ids = []
        all_batches = []
        
        for user in users:
            print(f"\n   Student: {user.first_name} {user.last_name}")
            user_batches = user.batches if hasattr(user, 'batches') else []
            print(f"   Direct batches: {len(user_batches)}")
            
            for batch in user_batches:
                print(f"     - {batch.name} (ID: {batch.id}, Active: {batch.is_active})")
                if batch.id not in all_batch_ids and batch.is_active:
                    all_batch_ids.append(batch.id)
                    all_batches.append({
                        'id': batch.id,
                        'name': batch.name,
                        'description': batch.description
                    })
        
        print(f"\n   📦 Session would contain:")
        print(f"      allBatchIds: {all_batch_ids}")
        print(f"      batches: {[b['name'] for b in all_batches]}")
        
        if all_batch_ids:
            print(f"\n   ✅ Student should see exams from {len(all_batch_ids)} batch(es)")
        else:
            print(f"\n   ❌ WARNING: No batches found! Student won't see any exams")

print("\n" + "=" * 60)
