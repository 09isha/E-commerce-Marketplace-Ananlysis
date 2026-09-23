"""
generate_data.py — Synthetic E-commerce Marketplace Data Generator
=================================================================
Generates a realistic SQLite database (ecommerce.db) with 5 tables:
  users, events, products, orders, order_items, experiments

Uses ONLY Python standard library (no pip installs needed).

Run:  python generate_data.py
"""

import sqlite3
import random
import os
from datetime import datetime, timedelta

# ── Configuration ─────────────────────────────────────────────────────────────

SEED = 42
DB_NAME = "ecommerce.db"

NUM_USERS = 2000
NUM_PRODUCTS = 50
# Date range: 6 months (Jan 1 – Jun 30, 2024)
START_DATE = datetime(2024, 1, 1)
END_DATE = datetime(2024, 6, 30)

TRAFFIC_SOURCES = ["organic", "paid_search", "social", "direct", "email"]
TRAFFIC_WEIGHTS = [0.30, 0.25, 0.20, 0.15, 0.10]

DEVICE_TYPES = ["desktop", "mobile", "tablet"]
DEVICE_WEIGHTS = [0.45, 0.45, 0.10]

COUNTRIES = ["US", "UK", "India", "Germany", "Canada"]
COUNTRY_WEIGHTS = [0.40, 0.25, 0.15, 0.12, 0.08]

CATEGORIES = {
    "Electronics": [
        ("Wireless Earbuds", 49.99), ("Phone Case", 14.99), ("USB-C Cable", 9.99),
        ("Portable Charger", 29.99), ("Bluetooth Speaker", 39.99),
        ("Laptop Stand", 34.99), ("Webcam HD", 59.99), ("Mouse Pad", 12.99),
        ("Screen Protector", 7.99), ("Smart Watch Band", 19.99),
    ],
    "Clothing": [
        ("Cotton T-Shirt", 19.99), ("Denim Jeans", 49.99), ("Hoodie", 39.99),
        ("Running Shorts", 24.99), ("Baseball Cap", 14.99),
        ("Socks 6-Pack", 12.99), ("Polo Shirt", 29.99), ("Windbreaker", 44.99),
        ("Beanie", 9.99), ("Sweatpants", 34.99),
    ],
    "Home & Kitchen": [
        ("Coffee Mug Set", 22.99), ("Cutting Board", 18.99), ("Water Bottle", 14.99),
        ("Kitchen Towels", 11.99), ("Spice Rack", 27.99),
        ("Candle Set", 16.99), ("Coasters 4-Pack", 9.99), ("Measuring Cups", 13.99),
        ("Oven Mitts", 10.99), ("Food Container Set", 24.99),
    ],
    "Books": [
        ("Python Crash Course", 29.99), ("Atomic Habits", 16.99),
        ("The Lean Startup", 14.99), ("Sapiens", 18.99), ("Deep Work", 15.99),
        ("Thinking Fast and Slow", 17.99), ("Zero to One", 16.99),
        ("The Design of Everyday Things", 19.99), ("Hooked", 14.99),
        ("Measure What Matters", 18.99),
    ],
    "Health & Beauty": [
        ("Vitamin D Supplements", 12.99), ("Sunscreen SPF 50", 14.99),
        ("Lip Balm 3-Pack", 7.99), ("Hand Cream", 9.99), ("Face Mask 10-Pack", 11.99),
        ("Hair Serum", 16.99), ("Toothbrush Electric", 34.99),
        ("Body Lotion", 13.99), ("Eye Drops", 8.99), ("First Aid Kit", 19.99),
    ],
}

# Funnel step probabilities (conditional: given user reached previous step)
# homepage_view → product_view → add_to_cart → checkout_start → purchase
FUNNEL_PROBS = {
    "homepage_view":  1.00,   # Everyone visits homepage
    "product_view":   0.65,   # 65% view a product
    "add_to_cart":    0.35,   # 35% of product viewers add to cart
    "checkout_start": 0.60,   # 60% of add-to-cart start checkout
    "purchase":       0.70,   # 70% of checkout starters purchase
}

# ── Helpers ───────────────────────────────────────────────────────────────────

def random_date(start, end):
    """Return a random datetime between start and end."""
    delta = end - start
    random_seconds = random.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=random_seconds)


def weighted_choice(options, weights):
    """random.choices wrapper for clarity."""
    return random.choices(options, weights=weights, k=1)[0]


# ── Database Setup ────────────────────────────────────────────────────────────

def create_tables(cursor):
    """Create all 5 tables with appropriate schemas."""

    cursor.executescript("""
        DROP TABLE IF EXISTS users;
        DROP TABLE IF EXISTS events;
        DROP TABLE IF EXISTS products;
        DROP TABLE IF EXISTS orders;
        DROP TABLE IF EXISTS order_items;
        DROP TABLE IF EXISTS experiments;

        CREATE TABLE users (
            user_id        INTEGER PRIMARY KEY,
            signup_date    TEXT NOT NULL,       -- ISO format YYYY-MM-DD
            traffic_source TEXT NOT NULL,
            device_type    TEXT NOT NULL,
            country        TEXT NOT NULL
        );

        CREATE TABLE events (
            event_id   INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id    INTEGER NOT NULL,
            event_name TEXT NOT NULL,
            event_date TEXT NOT NULL,           -- ISO format YYYY-MM-DD
            page_url   TEXT,
            FOREIGN KEY (user_id) REFERENCES users(user_id)
        );

        CREATE TABLE products (
            product_id   INTEGER PRIMARY KEY,
            product_name TEXT NOT NULL,
            category     TEXT NOT NULL,
            price        REAL NOT NULL
        );

        CREATE TABLE orders (
            order_id     INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id      INTEGER NOT NULL,
            order_total  REAL NOT NULL,
            order_date   TEXT NOT NULL,         -- ISO format YYYY-MM-DD
            order_status TEXT NOT NULL,         -- completed, refunded, cancelled
            FOREIGN KEY (user_id) REFERENCES users(user_id)
        );

        CREATE TABLE order_items (
            item_id    INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id   INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity   INTEGER NOT NULL,
            unit_price REAL NOT NULL,
            FOREIGN KEY (order_id)   REFERENCES orders(order_id),
            FOREIGN KEY (product_id) REFERENCES products(product_id)
        );

        CREATE TABLE experiments (
            assignment_id   INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id         INTEGER NOT NULL,
            experiment_name TEXT NOT NULL,
            variant         TEXT NOT NULL,      -- 'control' or 'treatment'
            assigned_date   TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(user_id)
        );
    """)


# ── Data Generators ───────────────────────────────────────────────────────────

def generate_users(cursor):
    """Generate 2,000 users with signups spread over 6 months."""
    users = []
    for uid in range(1, NUM_USERS + 1):
        signup = random_date(START_DATE, END_DATE)
        source = weighted_choice(TRAFFIC_SOURCES, TRAFFIC_WEIGHTS)
        device = weighted_choice(DEVICE_TYPES, DEVICE_WEIGHTS)
        country = weighted_choice(COUNTRIES, COUNTRY_WEIGHTS)
        users.append((uid, signup.strftime("%Y-%m-%d"), source, device, country))
    cursor.executemany(
        "INSERT INTO users VALUES (?, ?, ?, ?, ?)", users
    )
    return users


def generate_products(cursor):
    """Generate 50 products across 5 categories."""
    products = []
    pid = 1
    for category, items in CATEGORIES.items():
        for name, price in items:
            products.append((pid, name, category, price))
            pid += 1
    cursor.executemany(
        "INSERT INTO products VALUES (?, ?, ?, ?)", products
    )
    return products


def generate_events_and_orders(cursor, users, products):
    """
    For each user, simulate a behavioral funnel:
      homepage_view → product_view → add_to_cart → checkout_start → purchase

    Users may go through the funnel multiple times (1–4 sessions).
    Not every session converts; drop-off is probabilistic.
    """
    events = []
    orders = []
    order_items_list = []

    funnel_steps = list(FUNNEL_PROBS.keys())

    for uid, signup_date_str, source, device, country in users:
        signup_date = datetime.strptime(signup_date_str, "%Y-%m-%d")
        # Each user has 1–4 sessions over their lifetime
        num_sessions = random.randint(1, 4)

        for _ in range(num_sessions):
            # Session happens sometime after signup, before end of data window
            session_date = random_date(signup_date, END_DATE)
            session_str = session_date.strftime("%Y-%m-%d")

            reached_step = None
            for step in funnel_steps:
                if random.random() <= FUNNEL_PROBS[step]:
                    # User reached this step
                    page_url = {
                        "homepage_view":  "/",
                        "product_view":   f"/product/{random.randint(1, NUM_PRODUCTS)}",
                        "add_to_cart":    "/cart",
                        "checkout_start": "/checkout",
                        "purchase":       "/order-confirmation",
                    }[step]
                    events.append((uid, step, session_str, page_url))
                    reached_step = step
                else:
                    break  # User dropped off

            # If user completed a purchase, create an order
            if reached_step == "purchase":
                num_items = random.randint(1, 3)
                chosen_products = random.sample(products, num_items)
                total = 0.0
                items_for_order = []
                for prod in chosen_products:
                    qty = random.randint(1, 2)
                    price = prod[3]
                    total += qty * price
                    items_for_order.append((prod[0], qty, price))

                # 90% completed, 7% refunded, 3% cancelled
                status_roll = random.random()
                if status_roll < 0.90:
                    status = "completed"
                elif status_roll < 0.97:
                    status = "refunded"
                else:
                    status = "cancelled"

                orders.append((uid, round(total, 2), session_str, status))
                order_items_list.append(items_for_order)

    # Bulk insert events
    cursor.executemany(
        "INSERT INTO events (user_id, event_name, event_date, page_url) "
        "VALUES (?, ?, ?, ?)",
        events
    )

    # Insert orders and order_items (need order_id from each insert)
    for i, order in enumerate(orders):
        cursor.execute(
            "INSERT INTO orders (user_id, order_total, order_date, order_status) "
            "VALUES (?, ?, ?, ?)",
            order
        )
        order_id = cursor.lastrowid
        for prod_id, qty, price in order_items_list[i]:
            cursor.execute(
                "INSERT INTO order_items (order_id, product_id, quantity, unit_price) "
                "VALUES (?, ?, ?, ?)",
                (order_id, prod_id, qty, price)
            )

    return len(events), len(orders)


def generate_experiments(cursor, users):
    """
    A/B test: 'checkout_redesign'
    - Randomly assign ~40% of users to the experiment
    - 50/50 split between control and treatment
    - Treatment users get a slightly higher purchase conversion (baked into
      the data by giving treatment users one extra funnel attempt)
    """
    experiment_users = random.sample(users, k=int(len(users) * 0.40))
    assignments = []

    for uid, signup_date_str, source, device, country in experiment_users:
        signup_date = datetime.strptime(signup_date_str, "%Y-%m-%d")
        assigned_date = random_date(signup_date, END_DATE)
        variant = random.choice(["control", "treatment"])
        assignments.append((
            uid, "checkout_redesign", variant,
            assigned_date.strftime("%Y-%m-%d")
        ))

        # Treatment group: simulate a small uplift by giving them one
        # extra purchase opportunity (~15% chance of an extra conversion)
        if variant == "treatment" and random.random() < 0.15:
            order_date = random_date(assigned_date, END_DATE)
            order_date_str = order_date.strftime("%Y-%m-%d")

            # Insert an extra purchase event
            cursor.execute(
                "INSERT INTO events (user_id, event_name, event_date, page_url) "
                "VALUES (?, 'purchase', ?, '/order-confirmation')",
                (uid, order_date_str)
            )
            # Insert a small extra order
            product_id = random.randint(1, NUM_PRODUCTS)
            cursor.execute(
                "SELECT price FROM products WHERE product_id = ?", (product_id,)
            )
            price = cursor.fetchone()[0]
            qty = 1
            total = round(price * qty, 2)
            cursor.execute(
                "INSERT INTO orders (user_id, order_total, order_date, order_status) "
                "VALUES (?, ?, ?, 'completed')",
                (uid, total, order_date_str)
            )
            oid = cursor.lastrowid
            cursor.execute(
                "INSERT INTO order_items (order_id, product_id, quantity, unit_price) "
                "VALUES (?, ?, ?, ?)",
                (oid, product_id, qty, price)
            )

    cursor.executemany(
        "INSERT INTO experiments (user_id, experiment_name, variant, assigned_date) "
        "VALUES (?, ?, ?, ?)",
        assignments
    )
    return len(assignments)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    random.seed(SEED)

    # Remove old DB if exists
    db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), DB_NAME)
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    print("Creating tables...")
    create_tables(cursor)

    print("Generating products...")
    products = generate_products(cursor)
    print(f"  - {len(products)} products")

    print("Generating users...")
    users = generate_users(cursor)
    print(f"  - {len(users)} users")

    print("Generating events & orders...")
    num_events, num_orders = generate_events_and_orders(cursor, users, products)
    print(f"  - {num_events} events")
    print(f"  - {num_orders} orders")

    print("Generating experiment assignments...")
    num_exp = generate_experiments(cursor, users)
    print(f"  - {num_exp} experiment assignments")

    conn.commit()

    # Print summary counts
    print("\n[OK] Database created: ecommerce.db")
    print("-" * 40)
    for table in ["users", "events", "products", "orders", "order_items", "experiments"]:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        print(f"  {table:15s} - {count:,} rows")

    conn.close()
    print("\nDone!")


if __name__ == "__main__":
    main()
