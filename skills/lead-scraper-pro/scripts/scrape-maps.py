#!/usr/bin/env python3
"""Scrape Google Maps for leads"""
import csv, json, time, argparse, sys, re
from urllib.parse import quote

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Install: pip install requests beautifulsoup4")
    sys.exit(1)

def search_google_maps(query, max_results=50, delay=3):
    """Search Google Maps and extract business listings"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                       "AppleWebKit/537.36 (KHTML, like Gecko) "
                       "Chrome/120.0.0.0 Safari/537.36"
    }
    results = []
    start = 0
    
    while len(results) < max_results:
        url = f"https://www.google.com/maps/search/{quote(query)}/?start={start}"
        try:
            resp = requests.get(url, headers=headers, timeout=15)
            resp.raise_for_status()
        except requests.RequestException as e:
            print(f"[!] Request failed: {e}")
            break
        
        soup = BeautifulSoup(resp.text, "html.parser")
        
        # Extract business cards (basic extraction)
        cards = soup.select('[role="article"], .section-result, [data-result-index]')
        if not cards:
            print("[i] No more results found")
            break
        
        for card in cards:
            name_el = card.select_one(".section-result-title, .fontHeadlineSmall, h3")
            name = name_el.get_text(strip=True) if name_el else ""
            
            rating_el = card.select_one(".section-result-rating, .fontBodyMedium span, [aria-label*='stars']")
            rating = rating_el.get_text(strip=True) if rating_el else ""
            rating = re.search(r'[\d.]+', rating)
            rating = rating.group() if rating else ""
            
            addr_el = card.select_one(".section-result-location, .fontBodyMedium, .section-result-text")
            address = addr_el.get_text(strip=True) if addr_el else ""
            
            # Extract map URL
            link_el = card.select_one("a[href*='maps/place']")
            map_url = ""
            if link_el:
                href = link_el.get("href", "")
                if href.startswith("/"):
                    map_url = "https://www.google.com" + href
                else:
                    map_url = href
            
            if name:
                results.append({
                    "name": name,
                    "address": address,
                    "rating": rating,
                    "google_maps_url": map_url,
                    "source": "maps"
                })
            
            if len(results) >= max_results:
                break
        
        start += len(cards)
        time.sleep(delay)
    
    return results[:max_results]

def main():
    parser = argparse.ArgumentParser(description="Scrape Google Maps leads")
    parser.add_argument("--query", required=True, help="Search query (e.g., 'plumbers in Bangalore')")
    parser.add_argument("--output", default="leads.csv", help="Output file (.csv or .json)")
    parser.add_argument("--max", type=int, default=50, help="Max results (default: 50)")
    parser.add_argument("--delay", type=int, default=3, help="Delay between requests in seconds")
    
    args = parser.parse_args()
    
    print(f"[*] Searching: {args.query}")
    print(f"[*] Max results: {args.max}")
    
    leads = search_google_maps(args.query, args.max, args.delay)
    
    if not leads:
        print("[!] No leads found")
        sys.exit(1)
    
    ext = args.output.rsplit(".", 1)[-1].lower()
    
    if ext == "json":
        with open(args.output, "w") as f:
            json.dump({"query": args.query, "count": len(leads), "leads": leads}, f, indent=2)
    else:
        if not leads:
            print("[!] No leads to write")
            sys.exit(1)
        with open(args.output, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=leads[0].keys())
            writer.writeheader()
            writer.writerows(leads)
    
    print(f"\n[✓] Saved {len(leads)} leads to {args.output}")
    print(f"[i] Preview:")
    for l in leads[:3]:
        print(f"    • {l['name']} — {l.get('rating', '?')}⭐")

if __name__ == "__main__":
    main()