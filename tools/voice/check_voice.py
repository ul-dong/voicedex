# 녹음 팩 확인: 들어 보지 않고도 잡을 수 있는 문제를 ffmpeg 로 찾는다.
# 사용: python check_voice.py assets/voice   (gen_voice.command 가 녹음 뒤에 부른다)
#   - lines.json 의 모든 문장이 manifest 에 있고 파일이 있는지
#   - 길이 0.3~10초, 통합 음량 -16 LUFS ±2 (EBU R128, ffmpeg ebur128), 최대 -1 dBFS 이하, 무음 아님
# 문제가 있으면 목록을 찍고 1로 끝난다.
import json
import os
import re
import subprocess
import sys

out_dir = sys.argv[1]
lines_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lines.json")
manifest = json.load(open(os.path.join(out_dir, "manifest.json"), encoding="utf-8"))
lines = json.load(open(lines_path, encoding="utf-8"))

problems = []
for it in lines:
    if it["text"] not in manifest:
        problems.append(f"manifest 에 없음: {it['text']}")

rows = []
for text, f in manifest.items():
    path = os.path.join(out_dir, f)
    if not os.path.exists(path):
        problems.append(f"파일 없음: {f} {text}")
        continue
    r = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true,volumedetect",
         "-f", "null", "-"], capture_output=True, text=True)
    err = r.stderr
    dur = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err)
    secs = int(dur[1]) * 3600 + int(dur[2]) * 60 + float(dur[3]) if dur else 0.0
    lufs = re.findall(r"I:\s+(-?[\d.]+) LUFS", err)
    lufs = float(lufs[-1]) if lufs else -99.0
    peak = re.findall(r"Peak:\s+(-?[\d.inf]+) dBFS", err)
    peak = float(peak[-1]) if peak and peak[-1] != "-inf" else -99.0
    mean = re.search(r"mean_volume: (-?[\d.]+) dB", err)
    mean = float(mean[1]) if mean else -99.0
    rows.append((f, secs, lufs, peak, mean, text))
    if not 0.3 <= secs <= 10:
        problems.append(f"길이 이상 {secs:.2f}s: {f} {text}")
    if abs(lufs + 16) > 2:
        problems.append(f"음량 이상 {lufs:.1f} LUFS: {f} {text}")
    if peak > -0.5:
        problems.append(f"최대값 너무 큼 {peak:.1f} dBFS: {f} {text}")
    if mean < -45:
        problems.append(f"거의 무음 mean {mean:.1f} dB: {f} {text}")

if rows:
    secs = [r[1] for r in rows]
    lufs = [r[2] for r in rows]
    size = sum(os.path.getsize(os.path.join(out_dir, r[0])) for r in rows)
    print(f"녹음 {len(rows)}개, 길이 {min(secs):.2f}~{max(secs):.2f}s (합 {sum(secs):.0f}s), "
          f"음량 {min(lufs):.1f}~{max(lufs):.1f} LUFS, 최대 {max(r[3] for r in rows):.1f} dBFS, "
          f"용량 {size / 1024:.0f} KB")
for p in problems:
    print("문제:", p)
sys.exit(1 if problems else 0)
