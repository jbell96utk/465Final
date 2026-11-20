-- Online Bookstore Management System
PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;


-- PUBLISHERS

INSERT INTO Publisher
    (PublisherID, Name, Address, Website)
VALUES
    (1, 'Northstar Press', '12 Cedar Street, Portland, OR',
        'https://northstar.example'),
    (2, 'Lantern House Publishing', '85 Oak Avenue, Austin, TX',
        'https://lantern.example'),
    (3, 'Practical Systems Media', '44 Market Road, Denver, CO',
        'https://practical.example'),
    (4, 'Blue Harbor Books', '9 Bay Street, Boston, MA',
        'https://blueharbor.example');

-- AUTHORS

INSERT INTO Author
    (AuthorID, FirstName, LastName, Email, Bio)
VALUES
    (1, 'Mina', 'Patel', 'mina.patel@example.com',
        'Writer of technology and contemporary fiction.'),
    (2, 'Jordan', 'Lee', 'jordan.lee@example.com',
        'Author of fiction and collaborative works.'),
    (3, 'Ana', 'Morales', 'ana.morales@example.com',
        'Writer of literary fiction.'),
    (4, 'Theo', 'Brooks', 'theo.brooks@example.com',
        'Author of technology and adventure books.'),
    (5, 'Nia', 'Campbell', 'nia.campbell@example.com',
        'Writer and editor of contemporary stories.'),
    (6, 'Devon', 'Price', 'devon.price@example.com',
        'Contributor to collaborative literary projects.');

-- CUSTOMERS

INSERT INTO Customer
    (CustomerID, FirstName, LastName, Email, Phone, Address)
VALUES
    (1, 'Ava', 'Chen', 'ava.chen@example.com',
        '555-0101', '15 Pine Street, Portland, OR'),
    (2, 'Marcus', 'Johnson', 'marcus.johnson@example.com',
        '555-0102', '23 Lake Road, Austin, TX'),
    (3, 'Priya', 'Shah', 'priya.shah@example.com',
        '555-0103', '8 Hill Avenue, Denver, CO'),
    (4, 'Lucas', 'Bennett', 'lucas.bennett@example.com',
        '555-0104', '62 Maple Lane, Boston, MA'),
    (5, 'Sofia', 'Rivera', 'sofia.rivera@example.com',
        '555-0105', '31 Elm Street, Phoenix, AZ'),
    (6, 'Ethan', 'Miller', 'ethan.miller@example.com',
        '555-0106', '7 Willow Court, Seattle, WA');

-- BOOKS

INSERT INTO Book
    (BookID, PublisherID, Title, ISBN, Price,
     PublicationDate, Description, StockQuantity)
VALUES
    (101, 1, 'The Quiet Algorithm', '9781555550101', 14.99,
        '2024-03-12', 'A story about technology and discovery.', 27),

    (102, 2, 'Gardens of Orion', '9781555550102', 24.50,
        '2023-06-01', 'An imaginative science fiction novel.', 5),

    (103, 3, 'SQLite in Practice', '9781555550103', 39.99,
        '2024-10-15', 'A practical guide to relational databases.', 11),

    (104, 4, 'The Last Lighthouse', '9781555550104', 9.50,
        '2022-08-20', 'A coastal mystery.', 0),

    (105, 1, 'Deep Blue Skies', '9781555550105', 12.00,
        '2023-11-05', 'A novel about family and travel.', 18),

    (106, 3, 'Designing Small Systems', '9781555550106', 18.75,
        '2025-01-10', 'An introduction to practical system design.', 3),

    (107, 2, 'The Paper Kingdom', '9781555550107', 32.00,
        '2024-05-18', 'A fantasy novel about a hidden kingdom.', 7),

    (108, 4, 'A Map of Memory', '9781555550108', 16.25,
        '2025-02-14', 'A story about memories and identity.', 9),

    (109, 3, 'Practical Data Stories', '9781555550109', 29.95,
        '2024-09-01', 'Using data to explain real-world problems.', 14),

    (110, 1, 'The Orchard Key', '9781555550110', 11.99,
        '2022-04-22', 'A mystery set in a rural town.', 0);

-- BOOKAUTHORS

INSERT INTO BookAuthor
    (BookID, AuthorID, Role)
VALUES
    (101, 1, 'Author'),
    (102, 2, 'Author'),
    (102, 5, 'Co-author'),
    (103, 4, 'Author'),
    (104, 3, 'Author'),
    (105, 1, 'Author'),
    (105, 2, 'Co-author'),
    (106, 5, 'Author'),
    (107, 3, 'Author'),
    (107, 6, 'Co-author'),
    (108, 4, 'Author'),
    (108, 5, 'Co-author'),
    (109, 2, 'Author'),
    (110, 3, 'Author');

-- CUSTOMER ORDERS

INSERT INTO CustomerOrder
    (OrderID, CustomerID, OrderDate, TotalAmount,
     Status, ShippingAddress)
VALUES
    (1001, 1, '2025-01-12', 54.48, 'Delivered',
        '15 Pine Street, Portland, OR'),

    (1002, 2, '2025-01-18', 58.99, 'Shipped',
        '23 Lake Road, Austin, TX'),

    (1003, 3, '2025-02-02', 48.00, 'Delivered',
        '8 Hill Avenue, Denver, CO'),

    (1004, 1, '2025-02-14', 67.75, 'Processing',
        '15 Pine Street, Portland, OR'),

    (1005, 4, '2025-03-03', 76.97, 'Delivered',
        '62 Maple Lane, Boston, MA'),

    (1006, 5, '2025-03-20', 28.25, 'Cancelled',
        '31 Elm Street, Phoenix, AZ'),

    (1007, 2, '2025-04-05', 79.98, 'Processing',
        '23 Lake Road, Austin, TX'),

    (1008, 3, '2025-04-11', 36.49, 'Pending',
        '8 Hill Avenue, Denver, CO');

-- ORDER ITEMS

INSERT INTO OrderItem
    (OrderItemID, OrderID, BookID, Quantity, UnitPrice)
VALUES
    (2001, 1001, 101, 2, 14.99),
    (2002, 1001, 102, 1, 24.50),

    (2003, 1002, 103, 1, 39.99),
    (2004, 1002, 104, 2, 9.50),

    (2005, 1003, 105, 4, 12.00),

    (2006, 1004, 102, 2, 24.50),
    (2007, 1004, 106, 1, 18.75),

    (2008, 1005, 101, 3, 14.99),
    (2009, 1005, 107, 1, 32.00),

    (2010, 1006, 106, 1, 18.75),
    (2011, 1006, 104, 1, 9.50),

    (2012, 1007, 103, 2, 39.99),

    (2013, 1008, 105, 1, 12.00),
    (2014, 1008, 101, 1, 14.99),
    (2015, 1008, 104, 1, 9.50);

-- PAYMENTS

INSERT INTO Payment
    (PaymentID, OrderID, PaymentDate, Amount, Method, Status)
VALUES
    (5001, 1001, '2025-01-12', 30.00, 'Card', 'Completed'),
    (5002, 1001, '2025-01-12', 24.48, 'Gift Card', 'Completed'),
    (5003, 1002, '2025-01-18', 58.99, 'PayPal', 'Completed'),
    (5004, 1003, '2025-02-02', 48.00, 'Card', 'Completed'),
    (5005, 1004, '2025-02-14', 30.00, 'Card', 'Pending'),
    (5006, 1005, '2025-03-03', 76.97, 'Card', 'Completed'),
    (5007, 1006, '2025-03-20', 28.25, 'PayPal', 'Failed'),
    (5008, 1007, '2025-04-05', 40.00, 'Card', 'Completed'),
    (5009, 1007, '2025-04-05', 39.98, 'Card', 'Completed');

COMMIT;

-- BASIC VALIDATION

SELECT 'Customer' AS TableName, COUNT(*) AS RowCount FROM Customer
UNION ALL
SELECT 'Author', COUNT(*) FROM Author
UNION ALL
SELECT 'Publisher', COUNT(*) FROM Publisher
UNION ALL
SELECT 'Book', COUNT(*) FROM Book
UNION ALL
SELECT 'BookAuthor', COUNT(*) FROM BookAuthor
UNION ALL
SELECT 'CustomerOrder', COUNT(*) FROM CustomerOrder
UNION ALL
SELECT 'OrderItem', COUNT(*) FROM OrderItem
UNION ALL
SELECT 'Payment', COUNT(*) FROM Payment;

-- Preview multi-table view.
SELECT *
FROM v_order_summary
ORDER BY OrderID;