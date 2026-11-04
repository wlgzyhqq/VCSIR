"""Compile the maintained firmware; optionally compile the local ISA tests."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, struct, subprocess
from firmware_layout import check_layout

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tests', action='store_true', help='Compile 42 RV32I and 3 project tests; do not execute them')
parser.add_argument('--external-only',action='store_true',help='Build TF main without changing unused embedded boot images')
parser.add_argument('--target-isa',choices=['rv32i','rv32im'],default='rv32i')
parser.add_argument('--optimization',choices=['Os','O2','O3'],default='Os')
parser.add_argument('--output-dir',type=Path,default=root/'output/firmware')
parser.add_argument('--keep-software-multiply',action='store_true',help='Keep legacy shift/add helper for controlled comparison')
parser.add_argument('--gcc', default=os.environ.get('RISCV_GCC', 'C:/msys64/ucrt64/bin/riscv32-unknown-elf-gcc.exe'))
args = parser.parse_args()
gcc = Path(args.gcc)
if not gcc.is_file():
    found = shutil.which(args.gcc)
    if not found:
        raise SystemExit('RISC-V GCC not found; specify --gcc or RISCV_GCC')
    gcc = Path(found)
objcopy = gcc.with_name('riscv32-unknown-elf-objcopy.exe')
environment = dict(os.environ)
environment['PATH'] = str(gcc.parent) + os.pathsep + environment.get('PATH', '')
if (args.target_isa!='rv32i' or args.output_dir.resolve()!=(root/'output/firmware').resolve()) and not args.external_only:
    parser.error('Alternate ISA/output requires --external-only; preserve embedded boot images')
output_dir=args.output_dir if args.output_dir.is_absolute() else root/args.output_dir
soft_float_library = subprocess.check_output([str(gcc), '-march='+args.target_isa, '-mabi=ilp32',
    '-print-libgcc-file-name'], env=environment, text=True).strip()
assert '/'+args.target_isa+'/ilp32/' in soft_float_library.replace('\\','/'), 'Require matching ISA software-float ABI library'
flags = ['-march='+args.target_isa+'_zicsr_zifencei', '-mabi=ilp32', '-mno-relax', '-nostdlib',
         '-ffreestanding', '-fno-builtin', '-ffp-contract=off', '-fno-fast-math', '-'+args.optimization, '-flto', '-msmall-data-limit=0', '-Wl,--no-relax',
         '-T', str(root / 'firmware/link.ld')]
if args.keep_software_multiply:flags.append('-DFINAL_KEEP_SOFTWARE_MULTIPLY=1')
compiled_sources={}

def compile_image(name, sources, output, extra=()):
    for p in sources:compiled_sources[p.relative_to(root).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    output.mkdir(parents=True, exist_ok=True)
    elf = output / (name + '.elf')
    binary = output / (name + '.bin')
    subprocess.run([str(gcc), *flags, *extra, *map(str, sources), soft_float_library, '-o', str(elf)],
                   check=True, cwd=root, env=environment)
    subprocess.run([str(objcopy), '-O', 'binary', str(elf), str(binary)],
                   check=True, cwd=root, env=environment)
    data = binary.read_bytes()
    if not 0 < len(data) < 0x1e000:
        raise ValueError(f'{name}: executable overlaps the reserved private stack')
    return data

data = compile_image('demo', [root / 'firmware/start.S', root / 'firmware/demo.c',
                            root / 'firmware/uart_io.c', root / 'firmware/terminal_input.c',
                            root / 'firmware/uart_console.c',root / 'firmware/runtime.c',
                            root / 'firmware/ascii_screen.c',root / 'firmware/hdmi_terminal.c',
                            root / 'firmware/chat_ui.c',root / 'firmware/utf8_stream.c',root / 'firmware/dma_bench.c',
                            root / 'firmware/linear_driver.c',root / 'firmware/vector_math.c',root / 'firmware/vector_ops.c',root / 'firmware/network_layer.c',root / 'firmware/model_inference.c',
                            root / 'firmware/sd_loader.c',root / 'firmware/sd_image.c',root / 'firmware/tokenizer.c',root / 'firmware/llm_chat.c',root / 'firmware/cpu_bench.c'], output_dir,
                     ['-Wall', '-Wextra', '-Werror', '-Wl,-Map='+str(output_dir / 'demo.map')])
layout = check_layout(output_dir / 'demo.elf')
image = data + b'\0' * (-len(data) % 32)
lines = ['// Generated from demo.bin; little-endian 32-byte DDR bursts.',
         f'localparam BOOT_LINES={len(image)//32};', 'function [255:0] boot_line;',
         ' input [15:0] index;', ' begin case(index)']
for i in range(len(image)//32):
    lines.append(f" 16'd{i}:boot_line=256'h{int.from_bytes(image[i*32:(i+1)*32], 'little'):064x};")
lines += [' default:boot_line=0;', ' endcase end', 'endfunction']
boot = root / 'firmware/boot_image.vh'
new_boot = '\n'.join(lines) + '\n'
if not args.external_only and (not boot.exists() or boot.read_text() != new_boot):
    boot.write_text(new_boot, encoding='utf-8')
hex_path = root / 'firmware/demo.hex'
if not args.external_only:
    hex_path.write_text('\n'.join(f'{word[0]:08x}' for word in struct.iter_unpack('<I', image)) + '\n', encoding='ascii')
metadata = {'executable_bytes': len(data), 'boot_padded_bytes': len(image),
            'sha256': hashlib.sha256(data).hexdigest().upper(), 'isa': args.target_isa+'_zicsr_zifencei',
            'abi': 'ilp32', 'executed': False, 'optimization':args.optimization,
            'keep_software_multiply':args.keep_software_multiply,'flags':flags,
            'soft_float_library':soft_float_library,
            'soft_float_library_sha256':hashlib.sha256(Path(soft_float_library).read_bytes()).hexdigest(),
            'compiler':subprocess.check_output([str(gcc),'--version'],text=True).splitlines()[0],
            'source_sha256':compiled_sources, **layout}
(output_dir / 'firmware.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
print(f'DEMO compiled: {len(data)} executable bytes, {len(image)} boot bytes. No tests executed.')
if args.tests:
    target = root / 'build/tests'
    includes = ['-I', str(root / 'firmware/tests/include')]
    names = []
    for source in sorted((root / 'firmware/tests/rv32ui').glob('*.S')):
        name = 'rv32ui-' + source.stem
        compile_image(name, [source], target, includes)
        names.append(name)
    for source in sorted((root / 'firmware').glob('test_*.S')):
        compile_image(source.stem, [source], target)
        names.append(source.stem)
    (target / 'tests.json').write_text(json.dumps(names, indent=2) + '\n', encoding='utf-8')
    print(f'{len(names)} local test images compiled; none executed.')
