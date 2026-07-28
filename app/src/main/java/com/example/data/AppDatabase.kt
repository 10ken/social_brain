package com.example.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [
        Person::class,
        Group::class,
        GroupMemberRef::class,
        Relationship::class,
        SocialEvent::class,
        EventAttendeeRef::class,
        Memory::class,
        Capture::class,
        Reminder::class,
        AppSettingsEntity::class
    ],
    version = 7,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun personDao(): PersonDao
    abstract fun groupDao(): GroupDao
    abstract fun relationshipDao(): RelationshipDao
    abstract fun socialEventDao(): SocialEventDao
    abstract fun memoryDao(): MemoryDao
    abstract fun captureDao(): CaptureDao
    abstract fun reminderDao(): ReminderDao
    abstract fun appSettingsDao(): AppSettingsDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE people ADD COLUMN isSelf INTEGER NOT NULL DEFAULT 0")
            }
        }

        val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE app_settings ADD COLUMN timeZone TEXT NOT NULL DEFAULT 'EST'")
            }
        }

        /** Adds sync identity and the documented evidence/archive fields without discarding user data. */
        val MIGRATION_6_7 = object : Migration(6, 7) {
            override fun migrate(db: SupportSQLiteDatabase) {
                val now = System.currentTimeMillis()
                fun add(table: String, column: String, definition: String) {
                    db.execSQL("ALTER TABLE $table ADD COLUMN $column $definition")
                }
                fun syncMetadata(table: String, timestampColumn: String? = "createdAt") {
                    add(table, "updatedAt", "INTEGER NOT NULL DEFAULT 0")
                    add(table, "deletedAt", "INTEGER")
                    add(table, "syncId", "TEXT NOT NULL DEFAULT ''")
                    val timestamp = timestampColumn?.let { "COALESCE($it, $now)" } ?: now.toString()
                    db.execSQL("UPDATE $table SET updatedAt = $timestamp")
                    db.execSQL("UPDATE $table SET syncId = " +
                        "lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-' || " +
                        "lower(hex(randomblob(2))) || '-' || lower(hex(randomblob(2))) || '-' || lower(hex(randomblob(6)))")
                }

                add("people", "sourceId", "INTEGER")
                add("people", "evidenceText", "TEXT")
                add("people", "archivedAt", "INTEGER")
                syncMetadata("people")
                add("groups", "archivedAt", "INTEGER")
                syncMetadata("groups")
                syncMetadata("group_members", null)
                add("relationships", "sourceId", "INTEGER")
                add("relationships", "evidenceText", "TEXT")
                add("relationships", "archivedAt", "INTEGER")
                syncMetadata("relationships")
                add("social_events", "evidenceText", "TEXT")
                add("social_events", "dateText", "TEXT")
                add("social_events", "createdAt", "INTEGER NOT NULL DEFAULT 0")
                db.execSQL("UPDATE social_events SET createdAt = $now WHERE createdAt = 0")
                add("social_events", "archivedAt", "INTEGER")
                syncMetadata("social_events")
                syncMetadata("event_attendees", null)
                add("memories", "evidenceText", "TEXT")
                add("memories", "archivedAt", "INTEGER")
                syncMetadata("memories")
                syncMetadata("captures")
                add("reminders", "groupId", "INTEGER")
                add("reminders", "sourceId", "INTEGER")
                add("reminders", "evidenceText", "TEXT")
                add("reminders", "confidenceState", "TEXT NOT NULL DEFAULT 'confirmed'")
                add("reminders", "archivedAt", "INTEGER")
                syncMetadata("reminders")
                add("app_settings", "syncId", "TEXT NOT NULL DEFAULT ''")
                db.execSQL("UPDATE app_settings SET syncId = " +
                    "lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-' || " +
                    "lower(hex(randomblob(2))) || '-' || lower(hex(randomblob(2))) || '-' || lower(hex(randomblob(6)))")
            }
        }

        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "social_memory_database"
                )
                .addMigrations(MIGRATION_2_3, MIGRATION_5_6, MIGRATION_6_7)
                .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
