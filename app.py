#!/usr/bin/env python3
"""Interactive command-line application for the Online Bookstore database."""

from __future__ import annotations

import os
import sqlite3
import sys
from contextlib import contextmanager
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Iterable, Sequence

BASE_DIR = Path(__file__).resolve().parent

def configured_database_path() -> Path:
    value = os.environ.get("BOOKSTORE_DB", "online_bookstore.db")
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = BASE_DIR / path
    return path.resolve()


DB_PATH = configured_database_path()
SCHEMA_PATH = BASE_DIR / "schema.sql"
SEED_PATH = BASE_DIR / "insert_data.sql"


class AppError(Exception):
    """An expected, user-facing application error."""


@contextmanager
def database_connection():
    """Open a connection with FK enforcement and always close it."""
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def initialize_database_if_needed() -> bool:
    """Create and seed a new database only when the database file is absent/empty."""
    if DB_PATH.exists() and DB_PATH.stat().st_size > 0:
        return False

    if not SCHEMA_PATH.is_file() or not SEED_PATH.is_file():
        raise AppError(
            "A new database is needed, but schema.sql and/or insert_data.sql "
            "is missing. Put both files beside app.py."
        )

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    try:
        with database_connection() as conn:
            conn.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
            conn.execute("PRAGMA foreign_keys = ON")
            if conn.execute("PRAGMA foreign_keys").fetchone()[0] != 1:
                raise AppError("SQLite foreign-key enforcement could not be enabled.")
            conn.executescript(SEED_PATH.read_text(encoding="utf-8"))
            violations = conn.execute("PRAGMA foreign_key_check").fetchall()
            if violations:
                raise AppError("The sample data contains foreign-key violations.")
    except Exception:
        # Do not leave a half-created file that looks like a usable database.
        try:
            if DB_PATH.exists():
                DB_PATH.unlink()
        except OSError:
            pass
        raise

    return True


def validate_existing_database() -> None:
    required = {
        "Customer", "Author", "Publisher", "Book", "BookAuthor",
        "CustomerOrder", "OrderItem", "Payment", "v_order_summary"
    }
    with database_connection() as conn:
        found = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type IN ('table', 'view')"
            )
        }
    missing = sorted(required - found)
    if missing:
        raise AppError(
            "The existing database is missing required objects: "
            + ", ".join(missing)
            + ". Back up and remove the database file, then restart the app "
            "to recreate it from the supplied SQL files."
        )


def read_text(prompt: str, *, required: bool = True, max_length: int | None = None) -> str:
    while True:
        value = input(prompt).strip()
        if required and not value:
            print("Please enter a value.")
            continue
        if max_length is not None and len(value) > max_length:
            print(f"Please use {max_length} characters or fewer.")
            continue
        return value


def read_int(
    prompt: str,
    *,
    minimum: int | None = None,
    maximum: int | None = None,
    allow_blank: bool = False,
    default: int | None = None,
) -> int | None:
    while True:
        raw = input(prompt).strip()
        if allow_blank and raw == "":
            return default
        try:
            value = int(raw)
        except ValueError:
            print("Please enter a whole number.")
            continue
        if minimum is not None and value < minimum:
            print(f"Please enter a number of at least {minimum}.")
            continue
        if maximum is not None and value > maximum:
            print(f"Please enter a number no greater than {maximum}.")
            continue
        return value


def read_money(prompt: str, *, minimum: Decimal = Decimal("0"), allow_blank: bool = False,
               default: Decimal | None = None) -> Decimal | None:
    while True:
        raw = input(prompt).strip()
        if allow_blank and raw == "":
            return default
        try:
            value = Decimal(raw)
        except InvalidOperation:
            print("Please enter a valid amount, such as 19.95.")
            continue
        if not value.is_finite() or value < minimum:
            print(f"Please enter an amount of at least {minimum}.")
            continue
        if value.as_tuple().exponent < -2:
            print("Please enter no more than two digits after the decimal point.")
            continue
        return value.quantize(Decimal("0.01"))


def read_date(prompt: str, *, allow_blank: bool = False) -> str | None:
    while True:
        raw = input(prompt).strip()
        if allow_blank and not raw:
            return None
        try:
            parsed = date.fromisoformat(raw)
        except ValueError:
            print("Enter a valid date in YYYY-MM-DD format.")
            continue
        if parsed.isoformat() != raw:
            print("Use exactly YYYY-MM-DD format.")
            continue
        return raw


def read_yes_no(prompt: str, *, default: bool = False) -> bool:
    suffix = "[Y/n]" if default else "[y/N]"
    while True:
        raw = input(f"{prompt} {suffix}: ").strip().lower()
        if not raw:
            return default
        if raw in {"y", "yes"}:
            return True
        if raw in {"n", "no"}:
            return False
        print("Please answer yes or no.")


def money(value: object) -> str:
    return f"${Decimal(str(value or 0)).quantize(Decimal('0.01')):,.2f}"


def print_table(rows: Sequence[sqlite3.Row], columns: Sequence[tuple[str, str]] | None = None) -> None:
    if not rows:
        print("No matching records found.")
        return
    if columns is None:
        columns = [(key, key) for key in rows[0].keys()]
    rendered: list[list[str]] = []
    for row in rows:
        rendered.append([str(row[key]) if row[key] is not None else "" for key, _ in columns])
    widths = [min(38, max(len(label), *(len(line[i]) for line in rendered))) for i, (_, label) in enumerate(columns)]
    header = " | ".join(label.ljust(widths[i]) for i, (_, label) in enumerate(columns))
    rule = "-+-".join("-" * width for width in widths)
    print(header)
    print(rule)
    for line in rendered:
        cells = []
        for i, value in enumerate(line):
            if len(value) > widths[i]:
                value = value[: widths[i] - 1] + "…"
            cells.append(value.ljust(widths[i]))
        print(" | ".join(cells))


def handle_database_error(exc: sqlite3.Error) -> None:
    message = str(exc).lower()
    if isinstance(exc, sqlite3.IntegrityError):
        if "unique constraint failed" in message:
            print("That value is already in use. Check for a duplicate email, ISBN, or publisher name.")
        elif "foreign key constraint failed" in message:
            print("That operation refers to a record that does not exist or is still being used elsewhere.")
        elif "check constraint failed" in message or "not null constraint failed" in message:
            print("One or more values do not meet the database's required rules.")
        else:
            print("The database rejected that change because it would violate a data rule.")
    elif isinstance(exc, sqlite3.OperationalError):
        print("The database could not complete that operation. Check that the database is available and not locked.")
    else:
        print("The database operation could not be completed. No uncommitted changes were saved.")


def browse_books() -> None:
    term = read_text("Search title, ISBN, or author (blank for all books): ", required=False)
    in_stock_only = read_yes_no("Show only books currently in stock?", default=False)
    pattern = f"%{term}%"
    sql = """
        SELECT
            b.BookID,
            b.Title,
            b.ISBN,
            p.Name AS Publisher,
            b.Price,
            b.StockQuantity,
            COALESCE(GROUP_CONCAT(a.FirstName || ' ' || a.LastName, ', '), '') AS Authors
        FROM Book AS b
        JOIN Publisher AS p ON p.PublisherID = b.PublisherID
        LEFT JOIN BookAuthor AS ba ON ba.BookID = b.BookID
        LEFT JOIN Author AS a ON a.AuthorID = ba.AuthorID
        WHERE (
            ? = '' OR b.Title LIKE ? OR b.ISBN LIKE ? OR EXISTS (
                SELECT 1
                FROM BookAuthor AS bx
                JOIN Author AS ax ON ax.AuthorID = bx.AuthorID
                WHERE bx.BookID = b.BookID
                  AND (ax.FirstName LIKE ? OR ax.LastName LIKE ?)
            )
        )
          AND (? = 0 OR b.StockQuantity > 0)
        GROUP BY b.BookID, b.Title, b.ISBN, p.Name, b.Price, b.StockQuantity
        ORDER BY b.Title COLLATE NOCASE
    """
    with database_connection() as conn:
        rows = conn.execute(sql, (term, pattern, pattern, pattern, pattern, int(in_stock_only))).fetchall()
    display = []
    for row in rows:
        item = dict(row)
        item["Price"] = money(row["Price"])
        display.append(item)
    if not display:
        print("No matching books found.")
        return
    print_table(display, [(key, label) for key, label in [
        ("BookID", "Book ID"), ("Title", "Title"), ("Authors", "Authors"),
        ("Publisher", "Publisher"), ("Price", "Price"),
        ("StockQuantity", "In stock"), ("ISBN", "ISBN")
    ]])


def view_book_details() -> None:
    book_id = read_int("Book ID: ", minimum=1)
    with database_connection() as conn:
        book = conn.execute(
            """SELECT b.BookID, b.Title, b.ISBN, b.Price, b.PublicationDate,
                      b.Description, b.StockQuantity, p.Name AS Publisher,
                      p.Website AS PublisherWebsite
               FROM Book AS b
               JOIN Publisher AS p ON p.PublisherID = b.PublisherID
               WHERE b.BookID = ?""",
            (book_id,),
        ).fetchone()
        if book is None:
            print("No book was found with that ID.")
            return
        authors = conn.execute(
            """SELECT a.FirstName || ' ' || a.LastName AS AuthorName, ba.Role
               FROM BookAuthor AS ba
               JOIN Author AS a ON a.AuthorID = ba.AuthorID
               WHERE ba.BookID = ?
               ORDER BY a.LastName, a.FirstName""",
            (book_id,),
        ).fetchall()
    print(f"\n{book['Title']}  (Book ID {book['BookID']})")
    print(f"ISBN: {book['ISBN']}")
    print(f"Publisher: {book['Publisher']}")
    print(f"Publisher website: {book['PublisherWebsite'] or 'Not provided'}")
    print(f"Price: {money(book['Price'])}")
    print(f"Publication date: {book['PublicationDate'] or 'Not provided'}")
    print(f"Available stock: {book['StockQuantity']}")
    print(f"Description: {book['Description'] or 'Not provided'}")
    print("Authors:")
    if authors:
        for author in authors:
            print(f"  - {author['AuthorName']} ({author['Role']})")
    else:
        print("  No authors have been linked to this book yet.")


def register_customer() -> None:
    print("\nRegister a customer")
    first = read_text("First name: ", max_length=100)
    last = read_text("Last name: ", max_length=100)
    email = read_text("Email: ", max_length=254)
    if "@" not in email or email.startswith("@") or email.endswith("@"):
        print("Please enter an email address containing a valid @ separator.")
        return
    phone = read_text("Phone (optional): ", required=False, max_length=40)
    address = read_text("Address (optional): ", required=False, max_length=250)
    with database_connection() as conn:
        cur = conn.execute(
            "INSERT INTO Customer (FirstName, LastName, Email, Phone, Address) VALUES (?, ?, ?, ?, ?)",
            (first, last, email, phone or None, address or None),
        )
        customer_id = cur.lastrowid
    print(f"Customer registered successfully. Customer ID: {customer_id}")


def add_book() -> None:
    print("\nAdd a book to the catalog")
    with database_connection() as conn:
        publishers = conn.execute(
            "SELECT PublisherID, Name FROM Publisher ORDER BY Name"
        ).fetchall()
    if not publishers:
        print("There are no publishers. Add a publisher before adding a book.")
        return
    print_table(publishers, [("PublisherID", "Publisher ID"), ("Name", "Publisher")])
    publisher_id = read_int("Publisher ID: ", minimum=1)
    if not any(row["PublisherID"] == publisher_id for row in publishers):
        print("That publisher ID is not in the list.")
        return
    title = read_text("Title: ", max_length=200)
    isbn = read_text("ISBN: ", max_length=30)
    price = read_money("List price: ", minimum=Decimal("0.00"))
    publication_date = read_date("Publication date YYYY-MM-DD (blank if unknown): ", allow_blank=True)
    description = read_text("Description (optional): ", required=False, max_length=2000)
    stock = read_int("Initial stock quantity: ", minimum=0)
    with database_connection() as conn:
        cur = conn.execute(
            """INSERT INTO Book
               (PublisherID, Title, ISBN, Price, PublicationDate, Description, StockQuantity)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (publisher_id, title, isbn, float(price), publication_date, description or None, stock),
        )
        book_id = cur.lastrowid
    print(f"Book added successfully. Book ID: {book_id}")


def update_book() -> None:
    book_id = read_int("Book ID to update: ", minimum=1)
    with database_connection() as conn:
        book = conn.execute(
            "SELECT BookID, Title, Price, StockQuantity FROM Book WHERE BookID = ?",
            (book_id,),
        ).fetchone()
    if book is None:
        print("No book was found with that ID.")
        return
    print(f"{book['Title']} | Current price: {money(book['Price'])} | Stock: {book['StockQuantity']}")
    new_price = read_money(
        f"New price (Enter to keep {money(book['Price'])}): ",
        minimum=Decimal("0.00"), allow_blank=True, default=None,
    )
    new_stock = read_int(
        f"New stock quantity (Enter to keep {book['StockQuantity']}): ",
        minimum=0, allow_blank=True, default=None,
    )
    if new_price is None and new_stock is None:
        print("No changes requested.")
        return
    with database_connection() as conn:
        conn.execute(
            """UPDATE Book
               SET Price = COALESCE(?, Price),
                   StockQuantity = COALESCE(?, StockQuantity)
               WHERE BookID = ?""",
            (float(new_price) if new_price is not None else None, new_stock, book_id),
        )
    print("Book information updated successfully.")


def sales_report() -> None:
    print("\nBest-selling books for a date range")
    start_date = read_date("Start date (YYYY-MM-DD): ")
    end_date = read_date("End date (YYYY-MM-DD): ")
    if start_date > end_date:
        print("The start date must be on or before the end date.")
        return
    with database_connection() as conn:
        rows = conn.execute(
            """SELECT
                   b.BookID,
                   b.Title,
                   SUM(oi.Quantity) AS UnitsSold,
                   COUNT(DISTINCT co.OrderID) AS OrderCount,
                   ROUND(SUM(oi.Quantity * oi.UnitPrice), 2) AS SalesAmount
               FROM Book AS b
               JOIN OrderItem AS oi ON oi.BookID = b.BookID
               JOIN CustomerOrder AS co ON co.OrderID = oi.OrderID
               WHERE co.OrderDate BETWEEN ? AND ?
                 AND co.Status <> 'Cancelled'
               GROUP BY b.BookID, b.Title
               ORDER BY UnitsSold DESC, SalesAmount DESC, b.Title
            """,
            (start_date, end_date),
        ).fetchall()
    if not rows:
        print("No non-cancelled sales were found in that date range.")
        return
    display = []
    for row in rows:
        item = dict(row)
        item["SalesAmount"] = money(row["SalesAmount"])
        display.append(item)
    print_table(display, [
        ("BookID", "Book ID"), ("Title", "Title"),
        ("UnitsSold", "Units sold"), ("OrderCount", "Orders"),
        ("SalesAmount", "Sales amount"),
    ])


def customer_order_history() -> None:
    customer_id = read_int("Customer ID: ", minimum=1)
    with database_connection() as conn:
        customer = conn.execute(
            "SELECT CustomerID, FirstName, LastName, Email FROM Customer WHERE CustomerID = ?",
            (customer_id,),
        ).fetchone()
        if customer is None:
            print("No customer was found with that ID.")
            return
        rows = conn.execute(
            """SELECT
                   co.OrderID,
                   co.OrderDate,
                   co.Status AS OrderStatus,
                   b.Title,
                   oi.Quantity,
                   oi.UnitPrice,
                   ROUND(oi.Quantity * oi.UnitPrice, 2) AS LineTotal
               FROM CustomerOrder AS co
               LEFT JOIN OrderItem AS oi ON oi.OrderID = co.OrderID
               LEFT JOIN Book AS b ON b.BookID = oi.BookID
               WHERE co.CustomerID = ?
               ORDER BY co.OrderDate DESC, co.OrderID, b.Title
            """,
            (customer_id,),
        ).fetchall()
    print(f"\nOrder history for {customer['FirstName']} {customer['LastName']} ({customer['Email']})")
    if not rows:
        print("This customer has not placed any orders.")
        return
    display = []
    for row in rows:
        item = dict(row)
        item["UnitPrice"] = money(row["UnitPrice"]) if row["UnitPrice"] is not None else ""
        item["LineTotal"] = money(row["LineTotal"]) if row["LineTotal"] is not None else ""
        item["Title"] = item["Title"] or "(No line items)"
        display.append(item)
    print_table(display, [
        ("OrderID", "Order ID"), ("OrderDate", "Date"),
        ("OrderStatus", "Status"), ("Title", "Book"),
        ("Quantity", "Quantity"), ("UnitPrice", "Unit price"),
        ("LineTotal", "Line total"),
    ])


def place_order() -> None:
    print("\nPlace a new order")
    customer_id = read_int("Customer ID: ", minimum=1)
    with database_connection() as conn:
        customer = conn.execute(
            "SELECT CustomerID, FirstName, LastName, Address FROM Customer WHERE CustomerID = ?",
            (customer_id,),
        ).fetchone()
        if customer is None:
            print("No customer was found with that ID.")
            return
        default_address = customer["Address"] or ""
    print(f"Customer: {customer['FirstName']} {customer['LastName']}")
    address_prompt = "Shipping address"
    if default_address:
        address_prompt += f" (Enter to use {default_address})"
    address = read_text(address_prompt + ": ", required=False, max_length=250) or default_address
    if not address:
        address = read_text("Shipping address is required: ", max_length=250)

    selected: list[tuple[int, int]] = []
    selected_ids: set[int] = set()
    while True:
        with database_connection() as conn:
            catalog = conn.execute(
                "SELECT BookID, Title, Price, StockQuantity FROM Book WHERE StockQuantity > 0 ORDER BY Title"
            ).fetchall()
        if not catalog:
            print("No books are currently in stock.")
            return
        print("\nAvailable books:")
        display = []
        for row in catalog:
            item = dict(row)
            item["Price"] = money(row["Price"])
            display.append(item)
        print_table(display, [("BookID", "Book ID"), ("Title", "Title"),
                              ("Price", "Price"), ("StockQuantity", "Available")])
        book_id = read_int("Book ID to add (0 to finish): ", minimum=0)
        if book_id == 0:
            break
        if book_id in selected_ids:
            print("That book is already in this order. Choose another book.")
            continue
        matching = next((row for row in catalog if row["BookID"] == book_id), None)
        if matching is None:
            print("Choose a Book ID from the available-books list.")
            continue
        quantity = read_int(f"Quantity (1-{matching['StockQuantity']}): ", minimum=1,
                            maximum=matching["StockQuantity"])
        selected.append((book_id, quantity))
        selected_ids.add(book_id)
        print(f"Added {quantity} x {matching['Title']} to the order draft.")

    if not selected:
        print("No books were selected. No order was created.")
        return

    record_payment = read_yes_no("Record a payment now?", default=False)
    method = None
    if record_payment:
        methods = ["Card", "PayPal", "Gift Card"]
        print("Payment methods: " + ", ".join(methods))
        method = read_text("Payment method: ", max_length=30)
        if method not in methods:
            print("That payment method is not supported. No order was created.")
            return

    try:
        with database_connection() as conn:
            # The immediate transaction reserves the write lock before inventory is checked.
            conn.execute("BEGIN IMMEDIATE")
            conn.execute(
                """INSERT INTO CustomerOrder
                   (CustomerID, OrderDate, TotalAmount, Status, ShippingAddress)
                   VALUES (?, ?, 0, 'Confirmed', ?)""",
                (customer_id, date.today().isoformat(), address),
            )
            order_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]

            for book_id, quantity in selected:
                book = conn.execute(
                    "SELECT Title, Price, StockQuantity FROM Book WHERE BookID = ?",
                    (book_id,),
                ).fetchone()
                if book is None:
                    raise AppError(f"Book ID {book_id} no longer exists. The order was cancelled.")
                if book["StockQuantity"] < quantity:
                    raise AppError(
                        f"Not enough stock for '{book['Title']}'. Available: {book['StockQuantity']}; "
                        f"requested: {quantity}. The order was cancelled."
                    )
                updated = conn.execute(
                    "UPDATE Book SET StockQuantity = StockQuantity - ? "
                    "WHERE BookID = ? AND StockQuantity >= ?",
                    (quantity, book_id, quantity),
                )
                if updated.rowcount != 1:
                    raise AppError(f"Inventory could not be reserved for '{book['Title']}'.")
                conn.execute(
                    "INSERT INTO OrderItem (OrderID, BookID, Quantity, UnitPrice) VALUES (?, ?, ?, ?)",
                    (order_id, book_id, quantity, book["Price"]),
                )

            total = Decimal(str(conn.execute(
                "SELECT TotalAmount FROM CustomerOrder WHERE OrderID = ?", (order_id,)
            ).fetchone()[0])).quantize(Decimal("0.01"))

            if record_payment:
                print(f"Order total: {money(total)}")
                amount = read_money(
                    f"Payment amount (up to {money(total)}): ",
                    minimum=Decimal("0.01"),
                )
                if amount > total:
                    raise AppError("Payment cannot exceed the order total. The order was cancelled.")
                conn.execute(
                    """INSERT INTO Payment
                       (OrderID, PaymentDate, Amount, Method, Status)
                       VALUES (?, ?, ?, ?, 'Completed')""",
                    (order_id, date.today().isoformat(), float(amount), method),
                )
            conn.commit()
    except AppError:
        raise

    print(f"Order #{order_id} created successfully. Order total: {money(total)}")
    if record_payment:
        print(f"Payment of {money(amount)} recorded using {method}.")
    else:
        print("No payment was recorded. The order has an outstanding balance.")


def order_summary_report() -> None:
    print("\nOrder and payment summary")
    print("1. All orders\n2. Orders with a balance due\n3. Orders by customer name")
    choice = read_int("Choose report: ", minimum=1, maximum=3)
    sql = """SELECT OrderID, CustomerName, OrderDate, OrderStatus, OrderTotal,
                    CompletedPaymentAmount, BalanceDue, TotalUnits
             FROM v_order_summary"""
    if choice == 2:
        sql += " WHERE BalanceDue > 0 AND OrderStatus <> 'Cancelled'"
    elif choice == 3:
        sql += " ORDER BY CustomerName, OrderDate DESC"
    else:
        sql += " ORDER BY OrderDate DESC, OrderID DESC"
    with database_connection() as conn:
        rows = conn.execute(sql).fetchall()
    if not rows:
        print("No orders match this report.")
        return
    display = []
    for row in rows:
        item = dict(row)
        for key in ("OrderTotal", "CompletedPaymentAmount", "BalanceDue"):
            item[key] = money(row[key])
        display.append(item)
    print_table(display, [
        ("OrderID", "Order ID"), ("CustomerName", "Customer"),
        ("OrderDate", "Date"), ("OrderStatus", "Status"),
        ("OrderTotal", "Order total"), ("CompletedPaymentAmount", "Paid"),
        ("BalanceDue", "Balance due"), ("TotalUnits", "Units"),
    ])


def show_menu() -> None:
    print("\n" + "=" * 64)
    print("       ONLINE BOOKSTORE MANAGEMENT SYSTEM")
    print("=" * 64)
    print("1. Search / browse books")
    print("2. View book details (publisher and authors)")
    print("3. Register a customer")
    print("4. Add a book to the catalog")
    print("5. Update a book's price or inventory")
    print("6. Sales report: best-selling books by date range")
    print("7. View a customer's order history")
    print("8. Place a new order")
    print("9. Order and payment summary")
    print("0. Exit")


def main() -> int:
    try:
        created = initialize_database_if_needed()
        validate_existing_database()
        if created:
            print(f"A new database was created and sample data was loaded: {DB_PATH}")
        else:
            print(f"Connected to database: {DB_PATH}")
    except (AppError, OSError, sqlite3.Error) as exc:
        print(f"Startup error: {exc}", file=sys.stderr)
        return 1

    operations = {
        "1": browse_books,
        "2": view_book_details,
        "3": register_customer,
        "4": add_book,
        "5": update_book,
        "6": sales_report,
        "7": customer_order_history,
        "8": place_order,
        "9": order_summary_report,
    }

    while True:
        show_menu()
        try:
            choice = input("Select an option: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nExiting. Goodbye!")
            return 0
        if choice == "0":
            print("Goodbye!")
            return 0
        action = operations.get(choice)
        if action is None:
            print("Invalid menu selection. Choose a number from 0 to 9.")
            continue
        try:
            action()
        except (EOFError, KeyboardInterrupt):
            print("\nOperation cancelled. Returning to the main menu.")
        except sqlite3.Error as exc:
            handle_database_error(exc)
        except AppError as exc:
            print(f"Unable to complete the operation: {exc}")
        except OSError:
            print("A file or database access problem occurred. Check folder permissions.")


if __name__ == "__main__":
    raise SystemExit(main())
