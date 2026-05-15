#include "internal.h"
#include "sqlite3.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

int db_open(const char *path, sqlite3 **db) {
    return sqlite3_open_v2(path, db,
                           SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE |
                           SQLITE_OPEN_FULLMUTEX, NULL);
}

void db_close(sqlite3 *db) {
    if (db) sqlite3_close_v2(db);
}

int db_create_schema(sqlite3 *db) {
    const char *sql =
        "CREATE TABLE IF NOT EXISTS scam_phones ("
        "  phone     TEXT PRIMARY KEY,"
        "  category  TEXT NOT NULL,"
        "  score     INTEGER NOT NULL,"
        "  reason    TEXT,"
        "  updated   INTEGER"
        ");"
        "CREATE TABLE IF NOT EXISTS scam_domains ("
        "  domain    TEXT PRIMARY KEY,"
        "  category  TEXT NOT NULL,"
        "  score     INTEGER NOT NULL,"
        "  reason    TEXT,"
        "  updated   INTEGER"
        ");"
        "CREATE TABLE IF NOT EXISTS db_meta ("
        "  key       TEXT PRIMARY KEY,"
        "  value     TEXT"
        ");"
        "INSERT OR IGNORE INTO db_meta VALUES ('version','0');"
        "INSERT OR IGNORE INTO db_meta VALUES ('record_count','0');";

    char *errmsg = NULL;
    int rc = sqlite3_exec(db, sql, NULL, NULL, &errmsg);
    if (errmsg) sqlite3_free(errmsg);
    return rc;
}

int db_get_version(sqlite3 *db) {
    sqlite3_stmt *stmt = NULL;
    sqlite3_prepare_v2(db,
        "SELECT value FROM db_meta WHERE key='version'", -1, &stmt, NULL);
    int ver = 0;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        ver = atoi((const char *)sqlite3_column_text(stmt, 0));
    }
    sqlite3_finalize(stmt);
    return ver;
}

int db_get_record_count(sqlite3 *db) {
    sqlite3_stmt *stmt = NULL;
    sqlite3_prepare_v2(db,
        "SELECT COUNT(*) FROM scam_phones", -1, &stmt, NULL);
    int count = 0;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        count = sqlite3_column_int(stmt, 0);
    }
    sqlite3_finalize(stmt);
    return count;
}

int db_lookup_phone(sqlite3 *db, const char *phone, ThreatAssessment *out) {
    sqlite3_stmt *stmt = NULL;
    int rc = sqlite3_prepare_v2(db,
        "SELECT score, category, reason FROM scam_phones WHERE phone=?",
        -1, &stmt, NULL);
    if (rc != SQLITE_OK) return -1;

    sqlite3_bind_text(stmt, 1, phone, -1, SQLITE_STATIC);
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        out->risk_score = sqlite3_column_int(stmt, 0);
        strncpy(out->category,
                (const char *)sqlite3_column_text(stmt, 1),
                sizeof(out->category) - 1);
        const char *reason = (const char *)sqlite3_column_text(stmt, 2);
        if (reason) {
            strncpy(out->reason, reason, sizeof(out->reason) - 1);
        }
        sqlite3_finalize(stmt);
        return 0;
    }
    sqlite3_finalize(stmt);
    return -1; /* not found */
}

int db_lookup_domain(sqlite3 *db, const char *domain, ThreatAssessment *out) {
    sqlite3_stmt *stmt = NULL;
    int rc = sqlite3_prepare_v2(db,
        "SELECT score, category, reason FROM scam_domains WHERE domain=?",
        -1, &stmt, NULL);
    if (rc != SQLITE_OK) return -1;

    sqlite3_bind_text(stmt, 1, domain, -1, SQLITE_STATIC);
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        out->risk_score = sqlite3_column_int(stmt, 0);
        strncpy(out->category,
                (const char *)sqlite3_column_text(stmt, 1),
                sizeof(out->category) - 1);
        sqlite3_finalize(stmt);
        return 0;
    }
    sqlite3_finalize(stmt);
    return -1;
}

int db_apply_update(sqlite3 *db, const char *json_data) {
    /* Placeholder — in production parse JSON and INSERT OR REPLACE rows.
       Returns 0 on success. */
    (void)db; (void)json_data;
    return 0;
}
