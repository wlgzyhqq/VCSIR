"""Observe QSPI/TF boot without uploading any FPGA bitstream or firmware."""
from pathlib import Path
import argparse
import datetime
import json
import re
import subprocess
import time
from board_uart import BoardUART

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/reports/flash-step2e'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['reload', 'listen'], required=True)
    parser.add_argument('--port', default='COM12')
    parser.add_argument('--seconds', type=int, default=90)
    args = parser.parse_args()
    report = dict(started=datetime.datetime.now().astimezone().isoformat(),
        mode=args.mode, FPGA_bitstream_uploaded=False, firmware_uploaded=False,
        Flash_written=False, TF_written=False, boot_verified=False,
        cold_power_cycle_confirmed_by_user=False)
    base = OUT / ('boot-' + args.mode)
    try:
        with BoardUART(args.port, hold_boot=False) as uart:
            if args.mode == 'reload':
                commands = [
                    'cfg_set_tcl_break -flag true',
                    'cfg_connect -ip 127.0.0.1 -port 65420',
                    'cfg_scan_chain',
                    'cfg_reset_fpga -device_index 0',
                    'after 20000',
                    'cfg_read_device_property -device_index 0 -mode 3',
                    'exit',
                ]
                script = OUT / 'reload-from-flash.tcl'
                script.write_text('\n'.join(commands) + '\n', encoding='utf-8')
                with (OUT / 'reload-from-flash.log').open('wb') as stream:
                    result = subprocess.run(['D:/pango/PDS_2025.2-ads/bin/cdt_cfg_shell.exe'],
                        input=f'source {{{script.as_posix()}}}\nexit\n'.encode(),
                        stdout=stream, stderr=subprocess.STDOUT, timeout=60,
                        creationflags=subprocess.CREATE_NO_WINDOW, cwd=OUT)
                text = (OUT / 'reload-from-flash.log').read_text(errors='replace')
                print(text[-5000:], flush=True)
                assert result.returncode == 0 and not re.search(r'^E:', text, re.M)
                report['JTAG_configuration_reset_only'] = True
                report['configuration_done'] = bool(re.search(r'Bit 12:\s+1\s+done', text))
            deadline = time.monotonic() + args.seconds
            lines = []
            new_boot = False
            try:
                while time.monotonic() < deadline:
                    try:
                        line = uart.line(timeout=min(1, deadline-time.monotonic()))
                    except TimeoutError:
                        continue
                    # Power cycling can leave a NUL byte before the first UART
                    # banner. Preserve raw bytes in the log, normalize only this
                    # startup prefix for marker recognition.
                    line = line.lstrip('\x00')
                    if not new_boot:
                        if not line.startswith('@BOOT0_READY'):
                            continue
                        new_boot = True
                    print(line, flush=True)
                    lines.append(line)
                    (base.with_suffix('.log')).write_bytes(uart.raw)
                    if line.startswith('@YOLO_RESULT_READY') and any(s.startswith('@YOLO_READY') for s in lines):
                        break
                    if line.startswith(('@BOOT0_ERROR', '@YOLO_CARD_ERROR', '@YOLO_ASSET_FAIL', '@YOLO_FATAL', '@YOLO_INFER_ERROR')):
                        report['boot_error'] = line
                        break
            finally:
                (base.with_suffix('.log')).write_bytes(uart.raw)
            def find(prefix):
                return next((s for s in lines if s.startswith(prefix)), None)
            report.update(boot0_ready=find('@BOOT0_READY'),
                TF_firmware_bytes=find('@BOOT0_FW_BYTES'), TF_firmware_CRC=find('@BOOT0_CRC'),
                TF_firmware_verified=find('@BOOT0_VERIFIED'),
                main_firmware=find('@YOLO_BOOT'), hardware=find('@YOLO_HW'),
                application_ready=find('@YOLO_READY'), inference_result=find('@YOLO_RESULT '),
                inference_ready=find('@YOLO_RESULT_READY'))
            report['boot_verified'] = bool(report['boot0_ready'] and report['TF_firmware_verified']
                and report['application_ready'] and report['inference_ready'] and not report.get('boot_error'))
            assert report['boot_verified'], 'QSPI/TF application boot not yet verified; inspect log'
    except BaseException as exc:
        report['error'] = repr(exc)
        raise
    finally:
        base.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
