-- Online Bookstore Management System
PRAGMA foreign_keys = ON;

BEGIN IMMEDIATE;

-- Step 1: Create an order for customer 6.
INSERT INTO CustomerOrder (
    OrderID,
    CustomerID,
    OrderDate,
    TotalAmount,
    Status,
    ShippingAddress
)
VALUES (
    9001,
    6,
    '2025-04-15',
    0,
    'Confirmed',
    '7 Willow Court, Seattle, WA'
);

-- Step 2: Add two books to the new order.
INSERT INTO OrderItem (
    OrderItemID,
    OrderID,
    BookID,
    Quantity,
    UnitPrice
)
VALUES
    (90001, 9001, 108, 2, 16.25),
    (90002, 9001, 109, 1, 29.95);

-- Step 3: Decrease inventory for the two books purchased.
UPDATE Book
SET StockQuantity = StockQuantity - 2
WHERE BookID = 108
  AND StockQuantity >= 2;

UPDATE Book
SET StockQuantity = StockQuantity - 1
WHERE BookID = 109
  AND StockQuantity >= 1;

-- Step 4: Record the payment for the order.
INSERT INTO Payment (
    PaymentID,
    OrderID,
    PaymentDate,
    Amount,
    Method,
    Status
)
VALUES (
    90001,
    9001,
    '2025-04-15',
    62.45,
    'Card',
    'Completed'
);

-- Preview the changes while they are still inside the transaction.
SELECT
    OrderID,
    CustomerName,
    OrderTotal,
    CompletedPaymentAmount,
    BalanceDue
FROM v_order_summary
WHERE OrderID = 9001;

SELECT
    BookID,
    Title,
    StockQuantity AS TemporaryStockAfterOrder
FROM Book
WHERE BookID IN (108, 109)
ORDER BY BookID;

-- Roll back the order, its line items, inventory changes, and payment together.
ROLLBACK;

-- Confirm the rollback: TestOrderCount should be zero and stock should be restored.
SELECT
    COUNT(*) AS TestOrderCountAfterRollback
FROM CustomerOrder
WHERE OrderID = 9001;

SELECT
    BookID,
    Title,
    StockQuantity AS StockAfterRollback
FROM Book
WHERE BookID IN (108, 109)
ORDER BY BookID;
