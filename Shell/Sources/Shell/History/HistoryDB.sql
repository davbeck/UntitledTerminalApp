CREATE TABLE item (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    session_uuid       TEXT NOT NULL,
    input              TEXT NOT NULL,
    start_timestamp    REAL NOT NULL,
    end_timestamp      REAL NOT NULL,
    exit_code          INT NOT NULL
);

-- Setting a user version is useful for migrations. It can be used to
-- detect what schema version a database file has (and is also exposed
-- as a property in the generated Swift database structure).
PRAGMA user_version = 1;
