#!/usr/bin/env python3
"""
Script to check and troubleshoot IRC channel activity statistics
for MagIRC integration.
"""

import subprocess
import sys

def run_remote_mysql(query, description=""):
    """Execute MySQL query on remote server"""
    if description:
        print(f"\n=== {description} ===")
    
    cmd = [
        "ssh", "root@ceres.globalchat.org",
        f"mysql -u stats -pstats123 globalchat -e \"{query}\""
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"Error: {result.stderr}")
            return False
        return True
    except subprocess.TimeoutExpired:
        print("Query timed out")
        return False
    except Exception as e:
        print(f"Connection error: {e}")
        return False

def main():
    print("Checking IRC channel activity statistics...")
    
    # Check if stats_chanstats table exists and has data
    queries = [
        ("SELECT COUNT(*) as total_records FROM stats_chanstats;", 
         "Total records in stats_chanstats"),
        
        ("SELECT DISTINCT type FROM stats_chanstats ORDER BY type LIMIT 10;", 
         "Available statistic types"),
        
        ("SELECT chan, nick, type, letters, words, line, actions, smileys_happy FROM stats_chanstats WHERE letters > 0 ORDER BY letters DESC LIMIT 10;", 
         "Top users by activity (letters)"),
        
        ("SELECT chan, SUM(letters) as total_letters, SUM(words) as total_words, SUM(line) as total_lines FROM stats_chanstats WHERE type = 'total' GROUP BY chan ORDER BY total_letters DESC LIMIT 10;", 
         "Top channels by total activity"),
        
        ("SELECT DISTINCT chan FROM stats_chanstats ORDER BY chan LIMIT 20;", 
         "Channels with statistics"),
        
        ("SHOW CREATE TABLE stats_chanstats;", 
         "Table structure for stats_chanstats"),
        
        ("SELECT * FROM stats_chanstats WHERE DATE(time) = CURDATE() LIMIT 5;", 
         "Recent daily statistics (today)"),
    ]
    
    success_count = 0
    for query, desc in queries:
        if run_remote_mysql(query, desc):
            success_count += 1
        else:
            print("Skipping remaining queries due to connection issues.")
            break
    
    if success_count > 0:
        print(f"\nSuccessfully executed {success_count}/{len(queries)} queries")
        
        # Check if m_chanstats module is loaded
        print("\n=== Checking if m_chanstats module is loaded ===")
        run_remote_mysql("SELECT * FROM anope_info WHERE name LIKE '%chanstats%';", 
                        "Anope module status")
    else:
        print("\n❌ Could not connect to check statistics.")
        print("\nTROUBLESHOOTING STEPS:")
        print("1. SSH connection issues - verify server access")
        print("2. Check if Anope m_chanstats module is loaded")
        print("3. Verify chanstats.conf configuration")
        print("4. Check if stats_chanstats table exists")

if __name__ == "__main__":
    main()