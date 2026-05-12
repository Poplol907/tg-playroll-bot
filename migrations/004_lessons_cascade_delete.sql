-- Migration 004: cascade-delete lessons when student_teacher is deleted
--
-- Previously, deleting a StudentTeacher row left Lesson rows with a dangling
-- student_teacher_id FK. Those "ghost" lessons were unreachable via the
-- JOIN-based API endpoints (404 on DELETE/PATCH) but still showed up in
-- list queries through the Riverpod cache. Adding ON DELETE CASCADE ensures
-- lessons are automatically removed when their student_teacher record is gone.

ALTER TABLE lessons
    DROP CONSTRAINT IF EXISTS lessons_student_teacher_id_fkey;

ALTER TABLE lessons
    ADD CONSTRAINT lessons_student_teacher_id_fkey
    FOREIGN KEY (student_teacher_id)
    REFERENCES student_teachers(id)
    ON DELETE CASCADE;
