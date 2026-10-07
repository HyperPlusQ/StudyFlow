package com.hyperplusq.studyflow.data.db

import android.content.Context
import androidx.room.AutoMigration
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [
        SubjectEntity::class,
        AssignmentEntity::class,
        SubtaskEntity::class,
        TimeBlockEntity::class,
        SubmissionHistoryEntity::class,
        AttachmentEntity::class
    ],
    version = 2,
    autoMigrations = [AutoMigration(from = 1, to = 2)],
    exportSchema = true
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun subjectDao(): SubjectDao
    abstract fun assignmentDao(): AssignmentDao
    abstract fun subtaskDao(): SubtaskDao
    abstract fun timeBlockDao(): TimeBlockDao
    abstract fun submissionHistoryDao(): SubmissionHistoryDao
    abstract fun attachmentDao(): AttachmentDao

    companion object {
        @Volatile
        private var instance: AppDatabase? = null

        fun get(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "studyflow.db"
                ).build().also { instance = it }
            }
    }
}
