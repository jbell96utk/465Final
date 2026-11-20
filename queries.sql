-- Online Bookstore Management System

-- Requirement 1: Filtering and Sorting
-- Which books are currently in stock, and how many copies are available?
-- Books with available inventory are listed from highest stock to lowest.
SELECT
    BookID,
    Title,
    StockQuantity
FROM Book
WHERE StockQuantity > 0
ORDER BY StockQuantity DESC, Title ASC;


-- Requirement 2: INNER JOIN
-- Which publishers are associated with each book in the catalog?
-- Combines book details with the publisher responsible for each title.
SELECT
    b.BookID,
    b.Title,
    p.Name AS PublisherName,
    b.ISBN,
    b.Price
FROM Book AS b
INNER JOIN Publisher AS p
    ON p.PublisherID = b.PublisherID
ORDER BY p.Name, b.Title;


-- Requirement 3: LEFT JOIN
-- How many orders has each customer placed, including customers with no orders?
-- Customer 6 has no orders and should appear with an OrderCount of zero.
SELECT
    c.CustomerID,
    c.FirstName || ' ' || c.LastName AS CustomerName,
    COUNT(co.OrderID) AS OrderCount
FROM Customer AS c
LEFT JOIN CustomerOrder AS co
    ON co.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName
ORDER BY OrderCount DESC, CustomerName;


-- Requirement 4: Three-Table Join
-- What books have customers purchased, in what quantities, and on which orders?
-- Combines customers, orders, order items, and books to show purchase history.
-- Cancelled orders are excluded from completed/active purchase history.
SELECT
    c.CustomerID,
    c.FirstName || ' ' || c.LastName AS CustomerName,
    co.OrderID,
    co.OrderDate,
    b.Title,
    oi.Quantity,
    oi.UnitPrice,
    ROUND(oi.Quantity * oi.UnitPrice, 2) AS LineTotal
FROM Customer AS c
INNER JOIN CustomerOrder AS co
    ON co.CustomerID = c.CustomerID
INNER JOIN OrderItem AS oi
    ON oi.OrderID = co.OrderID
INNER JOIN Book AS b
    ON b.BookID = oi.BookID
WHERE co.Status <> 'Cancelled'
ORDER BY c.LastName, c.FirstName, co.OrderDate, b.Title;


-- Requirement 5: Aggregate Query
-- What was the bookstore's completed payment revenue from January through March 2025?
-- Uses SUM and COUNT without grouping so the query returns one overall summary row.
-- Pending and failed payments are not counted as revenue.
SELECT
    COUNT(*) AS CompletedPaymentCount,
    ROUND(COALESCE(SUM(Amount), 0), 2) AS CompletedRevenue
FROM Payment
WHERE Status = 'Completed'
  AND PaymentDate >= '2025-01-01'
  AND PaymentDate < '2025-04-01';


-- Requirement 6: GROUP BY and HAVING
-- Which authors are associated with more than one book?
-- Groups the junction records by author and returns authors with at least two titles.
SELECT
    a.AuthorID,
    a.FirstName || ' ' || a.LastName AS AuthorName,
    COUNT(DISTINCT ba.BookID) AS BookCount
FROM Author AS a
INNER JOIN BookAuthor AS ba
    ON ba.AuthorID = a.AuthorID
GROUP BY a.AuthorID, a.FirstName, a.LastName
HAVING COUNT(DISTINCT ba.BookID) > 1
ORDER BY BookCount DESC, AuthorName;


-- Requirement 7: Subquery
-- Which catalog books have never appeared on an order?
-- NOT EXISTS checks for the absence of a matching order-item record.
SELECT
    b.BookID,
    b.Title,
    b.StockQuantity,
    b.Price
FROM Book AS b
WHERE NOT EXISTS (
    SELECT 1
    FROM OrderItem AS oi
    WHERE oi.BookID = b.BookID
)
ORDER BY b.Title;


-- Requirement 8: Set Operation (UNION)
-- Which books need inventory attention because stock is low or no sales are recorded?
-- UNION combines related sets; a book meeting both conditions appears only once.
SELECT
    b.BookID,
    b.Title,
    'Requires review' AS AttentionReason
FROM Book AS b
WHERE b.StockQuantity <= 5

UNION

SELECT
    b.BookID,
    b.Title,
    'Requires review' AS AttentionReason
FROM Book AS b
WHERE NOT EXISTS (
    SELECT 1
    FROM OrderItem AS oi
    WHERE oi.BookID = b.BookID
)
ORDER BY Title, AttentionReason;


-- Requirement 9: View
-- Which non-cancelled orders still have a balance due?
-- Uses v_order_summary to retrieve order, customer, item, and completed-payment totals.
SELECT
    OrderID,
    CustomerName,
    OrderDate,
    OrderStatus,
    OrderTotal,
    CompletedPaymentAmount,
    BalanceDue,
    TotalUnits
FROM v_order_summary
WHERE OrderStatus <> 'Cancelled'
  AND BalanceDue > 0
ORDER BY OrderDate, OrderID;
