use std::env;
use std::error::Error;
use std::fmt;
use std::io::{Read, Write};
use std::mem::drop;
use std::net::{TcpListener, TcpStream};
use std::path::Path;
use std::str::FromStr;

use serde_json::Value;

use tokio;

use move_transactional_test_runner::framework::{MaybeNamedCompiledModule, MoveTestAdapter};
use move_bytecode_source_map::{source_map::SourceMap, utils::source_map_from_file};
use move_binary_format::file_format::CompiledModule;
use move_symbol_pool::Symbol;
use move_core_types::{
    account_address::AccountAddress, 
    language_storage::{TypeTag, StructTag}};

use sui_types::Identifier;
use sui_ctf_framework::NumericalAddress;
use sui_transactional_test_runner::{args::SuiValue, test_adapter::FakeID};

async fn handle_client(mut stream: TcpStream) -> Result<(), Box<dyn Error>> {
    
    // Initialize SuiTestAdapter
    let modules = vec!["challenge", "coin", "governance"];
    let sources = vec!["challenge", "coin", "governance"];
    let mut deployed_modules: Vec<AccountAddress> = Vec::new();

    let named_addresses = vec![
        (
            "challenge".to_string(),
            NumericalAddress::parse_str(
                "0x0", 
            )?,
        ),
        (
            "the_solution".to_string(),
            NumericalAddress::parse_str(
                "0x0",
            )?,
        ),
    ];

    let mut adapter = sui_ctf_framework::initialize(
        named_addresses,
        Some(vec!["challenger".to_string(), "solver".to_string()]),
    ).await;

    // Check Admin Account
    let object_output1 : Value = match sui_ctf_framework::view_object(&mut adapter, FakeID::Enumerated(0, 0)).await {
        Ok(output) => {
            println!("Object Output: {:#?}", output);
            output.unwrap()
        }
        Err(_error) => {
            // let _ = adapter.cleanup_resources().await;
            println!("[SERVER] Error viewing the object with ID 0:0");
            return Err("error when viewing the object with ID 0:0".into())
        }
    };
    
    let bytes_str = object_output1.get("Contents")
    .and_then(|contents| contents.get("id"))
    .and_then(|id| id.get("id"))
    .and_then(|inner_id| inner_id.get("bytes"))
    .and_then(|bytes| bytes.as_str())
    .unwrap();

    println!("Objet Bytes: {}", bytes_str);

    let mut mncp_modules : Vec<MaybeNamedCompiledModule> = Vec::new();

    for i in 0..modules.len() {

        let module = &modules[i];
        let _source = &sources[i];

        let mod_path = format!("./chall/build/challenge/bytecode_modules/{}.mv", module);
        let src_path = format!("./chall/build/challenge/debug_info/{}.json", module);

        let mod_bytes: Vec<u8> = std::fs::read(mod_path)?;

        let module: CompiledModule = match CompiledModule::deserialize_with_defaults(&mod_bytes) {
            Ok(data) => data,
            Err(e) => {
                return Err(Box::new(e))
            }
        }; 
        println!("All good here!");
        let named_addr_opt: Option<Symbol> = Some(Symbol::from("challenge"));
        let source_map: Option<SourceMap> = match source_map_from_file(Path::new(&src_path)) {
            Ok(data) => Some(data),
            Err(e) => {
                println!("error: {:?}, src_path: {}", e, src_path);
                return Err("error when generating source map".into())
            }
        };
        
        let maybe_ncm = MaybeNamedCompiledModule {
            named_address: named_addr_opt,
            module: module,
            source_map: source_map, 
        };
        
        mncp_modules.push( maybe_ncm );
          
    }

    // Publish Challenge Module
    let chall_dependencies: Vec<String> = Vec::new();
    let chall_addr = match sui_ctf_framework::publish_compiled_module(
        &mut adapter,
        mncp_modules,
        chall_dependencies,
        Some(String::from("challenger")),
    ).await {
        Some(addr) => addr,
        None => {
            stream.write("[SERVER] Error publishing module".as_bytes()).unwrap();
            return Ok(());
        }
    };

    deployed_modules.push(chall_addr);
    println!("[SERVER] Module published at: {:?}", chall_addr); 

    let mut solution_data = [0 as u8; 2000];
    let _solution_size = stream.read(&mut solution_data)?;

    // Send Challenge Address
    let mut output = String::new();
    fmt::write(
        &mut output,
        format_args!(
            "[SERVER] challenge modules published at: {}",
            chall_addr.to_string().as_str(),
        ),
    )
    .unwrap();
    stream.write(output.as_bytes()).unwrap();

    // Publish Solution Module
    let mut sol_dependencies: Vec<String> = Vec::new();
    sol_dependencies.push(String::from("challenge"));

    let mut mncp_solution : Vec<MaybeNamedCompiledModule> = Vec::new();
    let module : CompiledModule = CompiledModule::deserialize_with_defaults(&solution_data.to_vec()).unwrap();
    let named_addr_opt: Option<Symbol> = Some(Symbol::from("solution"));
    let source_map : Option<SourceMap> = None;
    
    let maybe_ncm = MaybeNamedCompiledModule {
        named_address: named_addr_opt,
        module: module,
        source_map: source_map,
    }; 
    mncp_solution.push( maybe_ncm );

    let sol_addr = match sui_ctf_framework::publish_compiled_module(
        &mut adapter,
        mncp_solution,
        sol_dependencies,
        Some(String::from("solver")),
    ).await {
        Some(addr) => addr,
        None => {
            stream.write("[SERVER] Error publishing module".as_bytes()).unwrap();
            // close tcp socket
            drop(stream);
            return Ok(());
        }
    };
    println!("[SERVER] Solution published at: {:?}", sol_addr);

    // Send Solution Address
    output = String::new();
    fmt::write(
        &mut output,
        format_args!(
            "[SERVER] Solution published at {}",
            sol_addr.to_string().as_str()
        ),
    )
    .unwrap();
    stream.write(output.as_bytes()).unwrap();

    let mut args_create : Vec<SuiValue> = Vec::new();
    let treasury_cap = SuiValue::Object(FakeID::Enumerated(2, 2), None); 
    args_create.push(treasury_cap);

    let ret_val = match sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        "challenge",
        "create",
        args_create,
        Vec::new(),
        Some("challenger".to_string()),
    ).await {
        Ok(output) => output,
        Err(e) => {
            println!("[SERVER] error: {e}");
            return Err("error during call to challenge::create".into())
        }
    };

    println!("[SERVER] Return value {:#?}", ret_val);

    for n in 0..3 {
        match sui_ctf_framework::view_object(&mut adapter, FakeID::Enumerated(2, n)).await {
            Ok(output) => {
                println!("OUR Output: {:#?}", output);
                output.unwrap()
            }
            Err(_error) => {
                // let _ = adapter.cleanup_resources().await;
                println!("[SERVER] Error viewing the object with ID 0:0");
                return Err("error when viewing the object with ID 0:0".into())
            }
        };
    }

    let mut solve_args : Vec<SuiValue> = Vec::new();
    let challenge_obj = SuiValue::Object(FakeID::Enumerated(4, 0), None);
    solve_args.push(challenge_obj);

    let ret_val = match sui_ctf_framework::call_function(
        &mut adapter,
        sol_addr,
        "solution",
        "solve",
        solve_args,
        Vec::new(),
        Some("solver".to_string()),
    ).await {
        Ok(output) => output,
        Err(e) => {
            println!("[SERVER] error: {e}");
            return Err("error during call to solution::solve".into())
        }
    };

    println!("[SERVER] Return value {:#?}", ret_val);

    let mut solve_args : Vec<SuiValue> = Vec::new();
    let challenge_obj = SuiValue::Object(FakeID::Enumerated(4, 0), None);
    solve_args.push(challenge_obj);

    let ret_val = match sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        "challenge",
        "is_solved",
        solve_args,
        Vec::new(),
        Some("solver".to_string()),
    ).await {
        Ok(output) => {
            println!("[SERVER] Correct Solution!");
            println!("");
            if let Ok(flag) = env::var("FLAG") {
                let message = format!("[SERVER] Congrats, flag: {}", flag);
                stream.write(message.as_bytes()).unwrap();
            } else {
                stream.write("[SERVER] Flag not found, please contact admin".as_bytes()).unwrap();
            }
        },
        Err(e) => {
            println!("[SERVER] error: {e}");
            return Err("error during call to challenge::is_solved".into())
        }
    };

    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Create Socket - Port 31337
    let listener = TcpListener::bind("0.0.0.0:31337")?;
    println!("[SERVER] Starting server at port 31337!");

    let local = tokio::task::LocalSet::new();

    // Wait For Incoming Solution
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                println!("[SERVER] New connection: {}", stream.peer_addr()?);
                    let _ = local.run_until( async move {
                        tokio::task::spawn_local( async {
                            handle_client(stream).await.unwrap();
                        }).await.unwrap();
                    }).await;
            }
            Err(e) => {
                println!("[SERVER] Error: {}", e);
            }
        }
    }

    // Close Socket Server
    drop(listener);
    Ok(())
}
