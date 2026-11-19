Feature: Required local database
  The service requires a usable file-backed local database.

  Scenario: Reject a database path that names a directory
    When the server starts with an unusable database file
    Then startup should fail because the database file cannot be opened

  Scenario Outline: Reject a database path that would use in-memory storage
    When the server starts with configuration "<config>"
    Then startup should fail database path validation with "<rule>"

    Examples:
      | config                   | rule     |
      | empty_database_path.yaml | required |
      | memory_database.yaml     | ne       |
