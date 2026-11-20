-- Online Bookstore Management System

PRAGMA foreign_keys = ON;

-- Remove existing objects so the database can be recreated.
DROP VIEW IF EXISTS v_order_summary;

DROP TABLE IF EXISTS Payment;
DROP TABLE IF EXISTS OrderItem;
DROP TABLE IF EXISTS BookAuthor;
DROP TABLE IF EXISTS CustomerOrder;
DROP TABLE IF EXISTS Book;
DROP TABLE IF EXISTS Author;
DROP TABLE IF EXISTS Publisher;
DROP TABLE IF EXISTS Customer;

BEGIN TRANSACTION;

-- 1. Customers
CREATE TABLE Customer (
    CustomerID INTEGER PRIMARY KEY,
    FirstName TEXT NOT NULL,
    LastName TEXT NOT NULL,
    Email TEXT NOT NULL UNIQUE,
    Phone TEXT,
    Address TEXT
);

-- 2. Authors
CREATE TABLE Author (
    AuthorID INTEGER PRIMARY KEY,
    FirstName TEXT NOT NULL,
    LastName TEXT NOT NULL,
    Email TEXT UNIQUE,
    Bio TEXT
);

-- 3. Publishers
CREATE TABLE Publisher (
    PublisherID INTEGER PRIMARY KEY,
    Name TEXT NOT NULL UNIQUE,
    Address TEXT,
    Website TEXT
);

-- 4. Books
CREATE TABLE Book (
    BookID INTEGER PRIMARY KEY,
    PublisherID INTEGER NOT NULL,
    Title TEXT NOT NULL,
    ISBN TEXT NOT NULL UNIQUE,
    Price REAL NOT NULL
        CHECK (Price >= 0),
    PublicationDate TEXT
        CHECK (
            PublicationDate IS NULL OR
            PublicationDate GLOB
            '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        ),
    Description TEXT,
    StockQuantity INTEGER NOT NULL DEFAULT 0
        CHECK (StockQuantity >= 0),

    FOREIGN KEY (PublisherID)
        REFERENCES Publisher(PublisherID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- 5. BookAuthor: resolves the Author-Book many-to-many relationship.
CREATE TABLE BookAuthor (
    BookID INTEGER NOT NULL,
    AuthorID INTEGER NOT NULL,
    Role TEXT NOT NULL DEFAULT 'Author'
        CHECK (
            Role IN (
                'Author',
                'Co-author',
                'Editor',
                'Illustrator',
                'Translator'
            )
        ),

    PRIMARY KEY (BookID, AuthorID),

    FOREIGN KEY (BookID)
        REFERENCES Book(BookID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (AuthorID)
        REFERENCES Author(AuthorID)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- 6. Customer orders
CREATE TABLE CustomerOrder (
    OrderID INTEGER PRIMARY KEY,
    CustomerID INTEGER NOT NULL,
    OrderDate TEXT NOT NULL
        CHECK (
            OrderDate GLOB
            '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        ),
    TotalAmount REAL NOT NULL DEFAULT 0
        CHECK (TotalAmount >= 0),
    Status TEXT NOT NULL DEFAULT 'Pending'
        CHECK (
            Status IN (
                'Pending',
                'Confirmed',
                'Processing',
                'Shipped',
                'Delivered',
                'Cancelled'
            )
        ),
    ShippingAddress TEXT NOT NULL,

    FOREIGN KEY (CustomerID)
        REFERENCES Customer(CustomerID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- 7. Order items: books and quantities included in each order.
CREATE TABLE OrderItem (
    OrderItemID INTEGER PRIMARY KEY,
    OrderID INTEGER NOT NULL,
    BookID INTEGER NOT NULL,
    Quantity INTEGER NOT NULL
        CHECK (Quantity > 0),
    UnitPrice REAL NOT NULL
        CHECK (UnitPrice >= 0),

    -- A book appears only once as a line in a particular order.
    UNIQUE (OrderID, BookID),

    FOREIGN KEY (OrderID)
        REFERENCES CustomerOrder(OrderID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    FOREIGN KEY (BookID)
        REFERENCES Book(BookID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- 8. Payments
CREATE TABLE Payment (
    PaymentID INTEGER PRIMARY KEY,
    OrderID INTEGER NOT NULL,
    PaymentDate TEXT NOT NULL
        CHECK (
            PaymentDate GLOB
            '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        ),
    Amount REAL NOT NULL
        CHECK (Amount > 0),
    Method TEXT NOT NULL
        CHECK (
            Method IN (
                'Card',
                'PayPal',
                'Bank Transfer',
                'Gift Card',
                'Cash'
            )
        ),
    Status TEXT NOT NULL DEFAULT 'Pending'
        CHECK (
            Status IN (
                'Pending',
                'Completed',
                'Failed',
                'Refunded'
            )
        ),

    FOREIGN KEY (OrderID)
        REFERENCES CustomerOrder(OrderID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

COMMIT;

-- indexes for frequent searches and joins.
CREATE INDEX idx_customerorder_customer_orderdate
    ON CustomerOrder(CustomerID, OrderDate DESC);

CREATE INDEX idx_orderitem_bookid
    ON OrderItem(BookID);

CREATE INDEX idx_bookauthor_authorid
    ON BookAuthor(AuthorID);

-- Keep an order's stored total synchronized with its line items.
-- TotalAmount is the sum of Quantity * UnitPrice.

CREATE TRIGGER trg_orderitem_after_insert
AFTER INSERT ON OrderItem
BEGIN
    UPDATE CustomerOrder
    SET TotalAmount = (
        SELECT COALESCE(SUM(Quantity * UnitPrice), 0.0)
        FROM OrderItem
        WHERE OrderID = NEW.OrderID
    )
    WHERE OrderID = NEW.OrderID;
END;

CREATE TRIGGER trg_orderitem_after_update
AFTER UPDATE OF OrderID, Quantity, UnitPrice ON OrderItem
BEGIN
    UPDATE CustomerOrder
    SET TotalAmount = (
        SELECT COALESCE(SUM(Quantity * UnitPrice), 0.0)
        FROM OrderItem
        WHERE OrderID = OLD.OrderID
    )
    WHERE OrderID = OLD.OrderID;

    UPDATE CustomerOrder
    SET TotalAmount = (
        SELECT COALESCE(SUM(Quantity * UnitPrice), 0.0)
        FROM OrderItem
        WHERE OrderID = NEW.OrderID
    )
    WHERE OrderID = NEW.OrderID;
END;

CREATE TRIGGER trg_orderitem_after_delete
AFTER DELETE ON OrderItem
BEGIN
    UPDATE CustomerOrder
    SET TotalAmount = (
        SELECT COALESCE(SUM(Quantity * UnitPrice), 0.0)
        FROM OrderItem
        WHERE OrderID = OLD.OrderID
    )
    WHERE OrderID = OLD.OrderID;
END;

-- multi-table view: one row per order with payment and item summaries.
-- Subqueries aggregate items and payments independently to avoid double-counting.

CREATE VIEW v_order_summary AS
SELECT
    co.OrderID,
    co.OrderDate,
    co.Status AS OrderStatus,
    c.CustomerID,
    c.FirstName || ' ' || c.LastName AS CustomerName,
    co.TotalAmount AS OrderTotal,

    COALESCE(i.ItemLineCount, 0) AS ItemLineCount,
    COALESCE(i.TotalUnits, 0) AS TotalUnits,

    COALESCE(p.CompletedPaymentAmount, 0.0)
        AS CompletedPaymentAmount,

    ROUND(
        co.TotalAmount -
        COALESCE(p.CompletedPaymentAmount, 0.0),
        2
    ) AS BalanceDue,

    COALESCE(p.PaymentRecordCount, 0) AS PaymentRecordCount

FROM CustomerOrder AS co

JOIN Customer AS c
    ON co.CustomerID = c.CustomerID

LEFT JOIN (
    SELECT
        OrderID,
        COUNT(*) AS ItemLineCount,
        SUM(Quantity) AS TotalUnits
    FROM OrderItem
    GROUP BY OrderID
) AS i
    ON co.OrderID = i.OrderID

LEFT JOIN (
    SELECT
        OrderID,
        COUNT(*) AS PaymentRecordCount,
        SUM(
            CASE
                WHEN Status = 'Completed' THEN Amount
                ELSE 0
            END
        ) AS CompletedPaymentAmount
    FROM Payment
    GROUP BY OrderID
) AS p
    ON co.OrderID = p.OrderID;