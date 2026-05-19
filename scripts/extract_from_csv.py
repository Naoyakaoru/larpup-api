import csv
from pathlib import Path
from datetime import datetime

def main():
    names_file = Path("names.txt")
    if not names_file.exists():
        print("錯誤：找不到 names.txt！請在 scripts/ 目錄下建立 names.txt，並填入要尋找的劇本名稱。")
        return

    # 讀取要尋找的名稱清單，轉為 set 以加速比對
    with open(names_file, "r", encoding="utf-8") as f:
        target_names = {line.strip() for line in f if line.strip()}

    if not target_names:
        print("錯誤：names.txt 裡面沒有內容！")
        return

    print(f"正在尋找 {len(target_names)} 筆劇本...")

    # 我們之前抓到的兩份大資料庫 (包含最新的 master)
    source_files = [
        "qiandao_scripts_20260518_1779117695.csv",
        "qiandao_scripts_tagged_master.csv"
    ]

    found_scripts = {}
    fieldnames = []

    for source in source_files:
        src_path = Path(source)
        if not src_path.exists():
            print(f"警告：找不到來源檔案 {source}，跳過。")
            continue

        print(f"正在掃描 {source} ...")
        with open(src_path, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            if not fieldnames:
                fieldnames = reader.fieldnames
            
            for row in reader:
                title = row.get("title", "").strip()
                # 若名稱在我們的目標清單內，且還沒被加入過（避免重複）
                if title in target_names and title not in found_scripts:
                    found_scripts[title] = row

    print(f"\n比對完成！共找到 {len(found_scripts)} 筆資料。")
    
    # 找出哪些沒有在資料庫裡
    missing = target_names - set(found_scripts.keys())
    if missing:
        print(f"以下 {len(missing)} 筆劇本在先前的資料庫中找不到：")
        for m in missing:
            print(f"  - {m}")
        print("（你可以把這些找不到的劇本放進另一個 names_missing.txt，再用 bulk_lookup.py 去抓基本資料）")

    if not found_scripts:
        print("\n沒有找到任何符合的資料，不產生 CSV。")
        return

    # 寫出結果
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_file = Path(f"extracted_scripts_{timestamp}.csv")
    
    with open(out_file, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in found_scripts.values():
            writer.writerow(row)
            
    print(f"\n已將找到的資料匯出至：scripts/{out_file.name}")

if __name__ == "__main__":
    main()
