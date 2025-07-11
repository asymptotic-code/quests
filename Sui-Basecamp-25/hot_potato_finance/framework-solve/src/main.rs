use std::env;
use std::io::{Read, Write};
use std::net::TcpStream;
use std::str::from_utf8;
use std::{error::Error, fs};

fn main() -> Result<(), Box<dyn Error>> {
    let host = env::var("HOST").unwrap_or_else(|_| "85.120.206.56".to_string());
    let port = env::var("PORT").unwrap_or_else(|_| "31339".to_string());

    match TcpStream::connect(format!("{}:{}", host, port)) {
        Ok(mut stream) => {
            println!("  - Connected!");

            let mod_data: Vec<u8> =
                fs::read("./solve/build/the_solution/bytecode_modules/solution.mv").unwrap();
            println!("  - Loaded solution!");

            stream.write_all(&mod_data)?;
            stream.flush()?;
            println!("  - Sent solution!");

            let mut return_data1 = [0 as u8; 200];
            match stream.read(&mut return_data1) {
                Ok(_) => {
                    println!(
                        "  - Connection Output: '{}'",
                        from_utf8(&return_data1).unwrap()
                    ); // Get module address
                    let mut return_data2 = [0 as u8; 200];
                    match stream.read(&mut return_data2) {
                        Ok(_) => {
                            println!(
                                "  - Connection Output: '{}'",
                                from_utf8(&return_data2).unwrap()
                            ); // Get module address
                            let mut flag = [0 as u8; 200];
                            match stream.read(&mut flag) {
                                Ok(_) => {
                                    println!(
                                        "  - Connection Output: '{}'",
                                        from_utf8(&flag).unwrap()
                                    ); // Get flag
                                }
                                Err(e) => {
                                    println!("  - Failed to receive data: {}", e);
                                }
                            }
                        }
                        Err(e) => {
                            println!("  - Failed to receive data: {}", e);
                        }
                    }
                }
                Err(e) => {
                    println!("  - Failed to connect: {}", e);
                }
            }
        }
        Err(e) => {
            println!("  - Failed to connect: {}", e);
        }
    }
    println!("  - Terminated.");

    Ok(())
}
