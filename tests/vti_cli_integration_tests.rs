use std::process::Command;

#[test]
fn vti_cli_headless_addams2_reports_pcm_activity() {
    let bin = env!("CARGO_BIN_EXE_vti-cli");
    let fixture = format!(
        "{}/crates/vti-core/tests/fixtures/tunes/madness_descent.pt3",
        env!("CARGO_MANIFEST_DIR")
    );

    let output = Command::new(bin)
        .arg(&fixture)
        .arg("--ticks")
        .arg("512")
        .output()
        .expect("failed to run vti-cli");

    assert!(output.status.success(), "vti-cli failed: {}", String::from_utf8_lossy(&output.stderr));

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("pcm_nonzero_total="), "stdout: {stdout}");

    let marker = "pcm_nonzero_total=";
    let value = stdout
        .split(marker)
        .nth(1)
        .and_then(|rest| rest.split_whitespace().next())
        .and_then(|v| v.parse::<usize>().ok())
        .expect("could not parse pcm_nonzero_last_tick value");

    assert!(value > 0, "expected non-zero PCM activity, stdout: {stdout}");
}

#[test]
fn vti_cli_without_arguments_fails_with_usage() {
    let bin = env!("CARGO_BIN_EXE_vti-cli");
    let output = Command::new(bin)
        .output()
        .expect("failed to run vti-cli");

    assert!(!output.status.success(), "expected non-zero exit code without arguments");
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("Usage: vti-cli"), "stderr: {stderr}");
}

#[cfg(feature = "cli")]
#[test]
fn vti_cli_headless_turbosound_reports_two_chips() {
    let bin = env!("CARGO_BIN_EXE_vti-cli");
    let fixture1 = format!(
        "{}/crates/vti-core/tests/fixtures/tunes/madness_descent.pt3",
        env!("CARGO_MANIFEST_DIR")
    );
    let fixture2 = format!(
        "{}/crates/vti-core/tests/fixtures/tunes/Space Crusade Loader.pt3",
        env!("CARGO_MANIFEST_DIR")
    );

    let output = Command::new(bin)
        .arg(&fixture1)
        .arg("--ts2")
        .arg(&fixture2)
        .arg("--ticks")
        .arg("256")
        .output()
        .expect("failed to run vti-cli");

    assert!(output.status.success(), "vti-cli failed: {}", String::from_utf8_lossy(&output.stderr));
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("chips=2"), "stdout: {stdout}");
}

#[cfg(feature = "cli")]
#[test]
fn vti_cli_headless_can_focus_turbosound_chip_two() {
    let bin = env!("CARGO_BIN_EXE_vti-cli");
    let fixture1 = format!(
        "{}/crates/vti-core/tests/fixtures/tunes/madness_descent.pt3",
        env!("CARGO_MANIFEST_DIR")
    );
    let fixture2 = format!(
        "{}/crates/vti-core/tests/fixtures/tunes/Space Crusade Loader.pt3",
        env!("CARGO_MANIFEST_DIR")
    );

    let output = Command::new(bin)
        .arg(&fixture1)
        .arg("--ts2")
        .arg(&fixture2)
        .arg("--active-chip")
        .arg("2")
        .arg("--ticks")
        .arg("16")
        .output()
        .expect("failed to run vti-cli");

    assert!(output.status.success(), "vti-cli failed: {}", String::from_utf8_lossy(&output.stderr));
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("active_chip=2"), "stdout: {stdout}");
}

