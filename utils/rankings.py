from sqlalchemy import func

from models import db, MonthlyExam, MonthlyRanking, MonthlyMark


def get_global_latest_rank_map(candidate_user_ids):
    """
    Find the latest exam rank map for a set of users across ALL batches.
    Useful fallback when a specific batch has no exams.
    """
    if not candidate_user_ids:
        return {}, None

    # 1. Try Rankings first (Finalized or otherwise)
    latest_ranked_exam = (
        MonthlyExam.query
        .join(MonthlyRanking, MonthlyRanking.monthly_exam_id == MonthlyExam.id)
        .filter(MonthlyRanking.user_id.in_(candidate_user_ids))
        .order_by(MonthlyExam.year.desc(), MonthlyExam.month.desc(), MonthlyExam.id.desc())
        .first()
    )

    if latest_ranked_exam:
        rankings = MonthlyRanking.query.filter_by(monthly_exam_id=latest_ranked_exam.id).all()
        rank_map = {}
        for row in rankings:
            current_rank = row.position or row.roll_number
            if current_rank:
                rank_map[row.user_id] = current_rank
        if rank_map:
            return rank_map, latest_ranked_exam

    # 2. Fallback to Marks
    latest_marked_exam = (
        MonthlyExam.query
        .join(MonthlyMark, MonthlyMark.monthly_exam_id == MonthlyExam.id)
        .filter(MonthlyMark.user_id.in_(candidate_user_ids))
        .order_by(MonthlyExam.year.desc(), MonthlyExam.month.desc(), MonthlyExam.id.desc())
        .first()
    )

    if latest_marked_exam:
        mark_rows = (
            db.session.query(
                MonthlyMark.user_id,
                func.sum(MonthlyMark.marks_obtained).label('total_obtained'),
                func.sum(MonthlyMark.total_marks).label('total_possible')
            )
            .filter(MonthlyMark.monthly_exam_id == latest_marked_exam.id)
            .group_by(MonthlyMark.user_id)
            .all()
        )

        scored = []
        max_obtained = 0
        for row in mark_rows:
            obtained = float(row.total_obtained or 0)
            if obtained > max_obtained:
                max_obtained = obtained
            possible = float(row.total_possible or 0)
            percentage = (obtained / possible * 100) if possible > 0 else 0
            scored.append((row.user_id, percentage, obtained))

        if scored and max_obtained > 0:
            scored.sort(key=lambda item: (-item[1], -item[2], item[0]))
            rank_map = {}
            for index, item in enumerate(scored, start=1):
                rank_map[item[0]] = index
            return rank_map, latest_marked_exam

    return {}, None


def get_batch_latest_rank_map(batch_id):
    """Return rank map for a batch using latest available monthly exam data.

    Priority:
    1) Latest exam with finalized MonthlyRanking rows having usable rank values.
    2) Latest exam with any MonthlyRanking rows having usable rank values.
    3) Latest exam with MonthlyMark rows (compute rank from total marks).

    Returns:
        tuple(dict, MonthlyExam|None): (rank_map, source_exam)
    """

    # 1/2: Try ranking table first (latest finalized preferred, then any ranking rows)
    ranked_exams = (
        MonthlyExam.query.join(MonthlyRanking, MonthlyRanking.monthly_exam_id == MonthlyExam.id)
        .filter(MonthlyExam.batch_id == batch_id)
        .order_by(MonthlyExam.year.desc(), MonthlyExam.month.desc(), MonthlyExam.id.desc())
        .all()
    )

    for exam in ranked_exams:
        finalized_rows = MonthlyRanking.query.filter_by(
            monthly_exam_id=exam.id,
            is_final=True
        ).all()

        candidate_rows = finalized_rows
        if not candidate_rows:
            candidate_rows = MonthlyRanking.query.filter_by(monthly_exam_id=exam.id).all()

        rank_map = {}
        for row in candidate_rows:
            current_rank = row.position or row.roll_number
            if current_rank:
                rank_map[row.user_id] = current_rank

        if rank_map:
            return rank_map, exam

    # 3: Fallback to exam marks and compute ranking on the fly (scan latest -> oldest)
    all_exams = (
        MonthlyExam.query.filter_by(batch_id=batch_id)
        .order_by(MonthlyExam.year.desc(), MonthlyExam.month.desc(), MonthlyExam.id.desc())
        .all()
    )

    if not all_exams:
        # Step 4: Fallback to Global Search (Cross-Batch Ranking)
        # If no exams exist for this specific batch, look for exams taken by these students in ANY batch
        from models import User, Batch, UserRole
        students = User.query.join(User.batches).filter(
            Batch.id == batch_id, 
            User.is_active == True,
            User.is_archived == False
        ).all()
        
        if students:
            student_ids = [s.id for s in students]
            global_rank_map, source_exam = get_global_latest_rank_map(student_ids)
            if global_rank_map:
                return global_rank_map, source_exam
        
        return {}, None

    for exam in all_exams:
        mark_rows = (
            db.session.query(
                MonthlyMark.user_id,
                func.sum(MonthlyMark.marks_obtained).label('total_obtained'),
                func.sum(MonthlyMark.total_marks).label('total_possible')
            )
            .filter(MonthlyMark.monthly_exam_id == exam.id)
            .group_by(MonthlyMark.user_id)
            .all()
        )

        if not mark_rows:
            continue

        scored = []
        max_obtained = 0
        for row in mark_rows:
            obtained = float(row.total_obtained or 0)
            if obtained > max_obtained:
                max_obtained = obtained
            possible = float(row.total_possible or 0)
            percentage = (obtained / possible * 100) if possible > 0 else 0
            scored.append((row.user_id, percentage, obtained))

        if not scored:
            continue

        # Skip exam if all students have 0 marks (likely just initialized but not taken)
        if max_obtained == 0:
            continue

        scored.sort(key=lambda item: (-item[1], -item[2], item[0]))

        rank_map = {}
        for index, item in enumerate(scored, start=1):
            rank_map[item[0]] = index

        return rank_map, exam

    # Step 4 (Late Fallback): If we had exams but none yielded a valid map (e.g. all empty marks), 
    # try the Global Fallback one last time.
    from models import User, Batch
    students = User.query.join(User.batches).filter(
        Batch.id == batch_id, 
        User.is_active == True,
        User.is_archived == False
    ).all()
    
    if students:
        student_ids = [s.id for s in students]
        global_rank_map, source_exam = get_global_latest_rank_map(student_ids)
        if global_rank_map:
            return global_rank_map, source_exam

    if all_exams:
         return {}, all_exams[0]
    return {}, None
