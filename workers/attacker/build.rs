// SPDX-License-Identifier: MIT
fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .build_server(false)
        .build_client(true)
        .compile(
            &["../../relay/src/worker/worker.proto"],
            &["../../relay/src/worker/"],
        )?;
    Ok(())
}