# Online Bookstore Management System

## Project Overview

The Online Bookstore Management System is a small database-driven
application for managing an online bookstore's catalog, customers,
orders, and payments. It is intended for bookstore staff or
administrators who need to maintain book and customer records, review
sales activity, and process customer orders.

The Python command-line application provides interactive operations to
search and browse books, view book details and their related authors and
publishers, register customers, add books, update prices and inventory,
review sales reports, view customer order histories, place orders, and
review order and payment summaries. Order processing updates inventory
and records order items and optional payments as one transaction.

The project includes an Entity-Relationship Diagram (`erd.png`), SQL
database schema and sample data, independent query and transaction
examples, a Bash test script, and the Python application.

## DBMS

The project uses SQLite, a file-based relational database management
system. The database file is named `online_bookstore.db` by default.

SQLite is accessed by the application through Python's standard-library
`sqlite3` module. The application enables foreign-key enforcement on
each database connection.

## Project Files

Keep the following files together in the project directory:

  -----------------------------------------------------------------------
  File                                Purpose
  ----------------------------------- -----------------------------------
  `erd.png`                           Entity-Relationship Diagram showing
                                      the database entities, keys, and
                                      relationships.

  `schema.sql`                        Creates the tables, primary and
                                      foreign keys, constraints, indexes,
                                      triggers, and `v_order_summary`
                                      view.

  `insert_data.sql`                   Inserts fictional sample records
                                      for testing.

  `queries.sql`                       Contains the separately labeled SQL
                                      queries for the database-query
                                      requirements.

  `transaction.sql`                   Demonstrates a multi-step database
                                      transaction.

  `run_queries.sh`                    Recreates the sample database and
                                      runs the query and transaction test
                                      files.

  `app.py`                            Interactive Python application.

  `README.md`                         Project setup and usage
                                      instructions.
                                      
  -----------------------------------------------------------------------

## Database Setup

### Required software

-   SQLite 3, including the `sqlite3` command-line program, to run the
    SQL files and Bash test script.
-   Bash to run `run_queries.sh`.
-   Python 3.10 or newer to run the application.


### Recreate the database manually

Open a terminal in the project directory and run these commands in
order:

``` bash
sqlite3 online_bookstore.db < schema.sql
sqlite3 online_bookstore.db < insert_data.sql
```

The schema file creates the database structure. The sample-data file
then inserts the demonstration records. Run the schema before the sample
data because the tables and constraints must exist before records can be
inserted.

SQLite foreign-key enforcement is enabled in the SQL setup and by the
Python application for each connection. If you open the database
manually in an interactive SQLite session and perform operations that
depend on foreign keys, enable enforcement in that session with:

``` sql
PRAGMA foreign_keys = ON;
```

### Run the SQL query and transaction tests

After creating the database, run the query file:

``` bash
sqlite3 -header -column online_bookstore.db < queries.sql
```

Then run the transaction demonstration:

``` bash
sqlite3 -bail online_bookstore.db < transaction.sql
```

The transaction example is intended to demonstrate related changes that
succeed or fail together. If the script uses `ROLLBACK` for its
demonstration, its test changes are not retained.

Alternatively, make the Bash script executable and run it:

``` bash
chmod +x run_queries.sh
bash run_queries.sh
```

The script is intended to remove and recreate the sample database, load
the sample data, display the query results, and execute the transaction
example. Running it resets the database file, so any changes made
through the application will be lost. Back up `online_bookstore.db`
first if you need to preserve those changes.

## Application Setup

### Language and libraries

The application is written in Python and uses:

-   Python 3.10 or newer
-   `sqlite3`, included with Python
-   Other Python standard-library modules

No third-party Python packages are required.

### Start the application

From the project directory, run:

``` bash
python app.py
```

If your system uses `python3` as the command, run:

``` bash
python3 app.py
```

When `online_bookstore.db` does not exist or is empty, the application
initializes it using `schema.sql` and `insert_data.sql`. Otherwise, it
connects to the existing database and preserves its stored data.

### Database location and configuration

By default, `online_bookstore.db` is created in the same directory as
`app.py`. No username, password, hosted service, or secret configuration
is required.

To use a different database file, set the `BOOKSTORE_DB` environment
variable before starting the application.

Linux or macOS:

``` bash
BOOKSTORE_DB="/path/to/online_bookstore.db" python3 app.py
```

Windows PowerShell:

``` powershell
$env:BOOKSTORE_DB = "C:\path\to\online_bookstore.db"
python app.py
```

When the application needs to initialize a new database, keep
`schema.sql` and `insert_data.sql` in the same directory as `app.py`.

To recreate the starter database, close the application and delete `online_bookstore.db`. Start the
application again and it will initialize a fresh database.

## Major Application Operations

Start `app.py` and select an option from the interactive menu:

1.  **Search and browse books:** Search by title, ISBN, or author, and
    optionally limit results to books currently in stock.
2.  **View book details:** Display a book's details along with its
    publisher and associated authors.
3.  **Register a customer:** Add a customer record.
4.  **Add a book:** Add a catalog entry associated with an existing
    publisher.
5.  **Update a book:** Change a book's price or available stock
    quantity.
6.  **Sales report:** Review best-selling books over a specified date
    range.
7.  **Customer order history:** View a customer's orders and the books
    included in them.
8.  **Place an order:** Create an order with one or more books, reduce
    inventory, and optionally record a payment. Related changes are
    handled within a database transaction.
9.  **Order and payment summary:** Review order totals, completed
    payments, and outstanding balances using the database view.

The application validates user input and uses parameterized SQL for
values supplied by the user. Database constraints provide additional
protection against invalid or inconsistent records.

## Known Limitations

There are no known limitations.
