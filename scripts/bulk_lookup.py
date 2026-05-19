import asyncio
import csv
import json
from pathlib import Path
from datetime import datetime

# 載入我們已經寫好的 Python 爬蟲邏輯
from qiandao_lookup import search_qiandao

async def main():
    names_file = Path("names.txt")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_file = Path(f"bulk_result_{timestamp}.csv")

    if not names_file.exists():
        print("錯誤：找不到 names.txt！請在 scripts/ 目錄下建立 names.txt，並在裡面填寫劇本名稱（一行一個）。")
        return

    with open(names_file, "r", encoding="utf-8") as f:
        names = [line.strip() for line in f if line.strip()]

    if not names:
        print("錯誤：names.txt 裡面沒有內容！")
        return

    print(f"開始抓取 {len(names)} 筆劇本資料（使用 Python 完整版本抓取幾男幾女與簡介）...")
    results = []

    for i, name in enumerate(names):
        print(f"[{i+1}/{len(names)}] 抓取: {name} ... ", end="", flush=True)
        
        # 呼叫已經寫好的 Python 函數 (裡面會自動去拿最完整的 feed API 資料)
        data = await search_qiandao(name)
        
        if data:
            results.append(data)
            print("成功！")
        else:
            print("找不到資料")
        
        # 暫停一下避免被千島鎖 IP
        await asyncio.sleep(1.5)

    if results:
        # 完全對齊 hot 500 的欄位名稱
        fieldnames = [
            "id", "title", "rating", "wish_count", "total_slots", 
            "male_slots", "female_slots", "any_slots", "allow_cross_gender", 
            "difficulty", "difficulty_norm", "genres", "genres_norm", 
            "duration_hours", "publisher", "cover_url", "cover_image_id", 
            "key_property_content", "description"
        ]

        with open(out_file, "w", encoding="utf-8-sig", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for row in results:
                # 計算總人數
                m = row.get("male_slots", 0)
                f_slots = row.get("female_slots", 0)
                a = row.get("any_slots", 0)
                total = (m or 0) + (f_slots or 0) + (a or 0)
                
                # 處理標籤
                genres_arr = row.get("genres", [])
                genres_norm = ",".join(map(str, genres_arr)) if genres_arr else ""

                csv_row = {
                    "id": row.get("qiandao_id", ""),
                    "title": row.get("title", ""),
                    "rating": "",
                    "wish_count": "",
                    "total_slots": total,
                    "male_slots": m,
                    "female_slots": f_slots,
                    "any_slots": a,
                    "allow_cross_gender": "True",
                    "difficulty": "",
                    "difficulty_norm": row.get("difficulty", ""),
                    "genres": "",
                    "genres_norm": genres_norm,
                    "duration_hours": row.get("duration") or "",
                    "publisher": row.get("publisher", ""),
                    "cover_url": row.get("cover_cdn_url", ""),
                    "cover_image_id": row.get("cover_image_id", ""),
                    "key_property_content": row.get("key_property", ""),
                    "description": row.get("description", "")
                }
                writer.writerow(csv_row)

    print(f"\n完成！所有找到的資料已儲存至 scripts/{out_file.name}")

if __name__ == "__main__":
    asyncio.run(main())
