module challenge::oracle;

use std::ascii::String;
use std::type_name;
use sui::table::{Self, Table};

public struct Price has copy, drop, store {
    price: u64,
    decimals: u8,
}

public struct PriceOracle has key, store {
    id: UID,
    prices: Table<String, Price>,
}

public(package) fun create(ctx: &mut TxContext): PriceOracle {
    PriceOracle {
        id: object::new(ctx),
        prices: table::new(ctx),
    }
}

public fun set_price<T>(self: &mut PriceOracle, price: u64, decimals: u8) {
    assert!(decimals <= 18);
    let key = type_name::get<T>().into_string();
    if (!self.prices.contains(key)) {
        self.prices.add(key, Price { price, decimals });
    } else {
        *self.prices.borrow_mut(key) = Price { price, decimals };
    }
}

public fun get_price<T>(self: &PriceOracle): Price {
    let key = type_name::get<T>().into_string();
    if (self.prices.contains(key)) {
        *self.prices.borrow(key)
    } else {
        Price { price: 0, decimals: 0 }
    }
}

public fun price(self: &Price): u64 {
    self.price
}

public fun decimals(self: &Price): u8 {
    self.decimals
}
