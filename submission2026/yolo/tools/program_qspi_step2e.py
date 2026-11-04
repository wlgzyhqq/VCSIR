"""Program the user-selected step2e FPGA image using PDS 2025; never write TF.

Requires the XT25BF128 custom entry installed through Fabric Configuration,
the conversion log, and a saved readback of the original configuration region.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/reports/flash-step2e'
BIT = ROOT / 'output/bitstream/yolo_step2e.sbit'
SFC = ROOT / 'output/bitstream/yolo_step2e_xt25bf128.sfc'
EXPECTED = 'cc757766bc2e0942f013bf9bd349eef6a23d04e047eba3c18eb98883f79acd40'
SHELL = 'D:/pango/PDS_2025.2-ads/bin/cdt_cfg_shell.exe'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--program', action='store_true', required=True)
    parser.parse_args()
    assert sha(BIT) == EXPECTED and sha(SFC) == EXPECTED
    backup = OUT / 'before-program.sfc'
    assert backup.is_file() and backup.stat().st_size == BIT.stat().st_size
    assert 'cfg_gen_sfc' in (OUT / 'prepare.log').read_text()
    target = OUT / 'after-erase-program.sfc'
    assert not target.exists(), 'Existing programming result: verify it before another write'
    report = dict(started=datetime.datetime.now().astimezone().isoformat(),
                  tool=SHELL, flash='XT25BF128', observed_JEDEC_ID='0x0b4018',
                  flash_capacity_bytes=16 * 1024 * 1024,
                  sbit=str(BIT), sbit_sha256=sha(BIT), sfc=str(SFC),
                  sfc_sha256=sha(SFC), backup=str(backup), backup_sha256=sha(backup),
                  backup_bytes=backup.stat().st_size,
                  TF_written=False, Flash_write_attempted=False,
                  Flash_program_verified=False, cold_power_boot_verified=False,
                  verification_method='Absolute-path Flash readback and host full byte comparison',
                  prior_attempt_report='program.json',
                  prior_attempt_issue='Program without erase produced exactly old-data AND new-data; built-in verify also failed opening a relative temporary file')
    def save():
        (OUT / 'program-erase.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    commands = [
        'cfg_set_tcl_break -flag true',
        'cfg_connect -ip 127.0.0.1 -port 65420',
        'cfg_scan_chain',
        'cfg_jtag_flash_scan_device -device_index 0',
        f'cfg_jtag_flash_assign_file -device_index 0 -file {{{SFC.as_posix()}}}',
        'cfg_jtag_flash_erase -device_index 0',
        'cfg_jtag_flash_program -device_index 0',
        f'cfg_jtag_flash_readback -device_index 0 -file {{{target.as_posix()}}}',
        'exit',
    ]
    script = OUT / 'program-erase-verify.tcl'
    script.write_text('\n'.join(commands) + '\n', encoding='utf-8')
    report['Flash_write_attempted'] = True
    save()
    try:
        print('Programming authorized step2e configuration; no TF writes.', flush=True)
        log = OUT / 'program-erase.log'
        with log.open('wb') as stream:
            result = subprocess.run([SHELL], input=f'source {{{script.as_posix()}}}\nexit\n'.encode(),
                stdout=stream, stderr=subprocess.STDOUT, timeout=300,
                creationflags=subprocess.CREATE_NO_WINDOW, cwd=OUT)
        text = log.read_text(errors='replace')
        print(text[-14000:], flush=True)
        report['exit_code'] = result.returncode
        assert result.returncode == 0 and not re.search(r'^E:', text, re.M), 'PDS operation failed'
        for op in ['cfg_jtag_flash_erase -device_index 0', 'cfg_jtag_flash_program -device_index 0']:
            assert f'Executing : {op} successfully.' in text, op
        assert target.read_bytes() == SFC.read_bytes(), 'Flash readback differs from requested SFC'
        report['Flash_program_verified'] = True
        report['readback_sha256'] = sha(target)
        report['readback_bytes'] = target.stat().st_size
        report['completed'] = datetime.datetime.now().astimezone().isoformat()
        print('PASS PDS erase/program and exact readback SHA256 verification.', flush=True)
    except BaseException as exc:
        report['error'] = repr(exc)
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
