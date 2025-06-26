#!/usr/bin/env python3
"""
Unicode East Asian Width Database Parser and Guile wcwidth Generator

This script downloads the official Unicode East Asian Width database
and generates a modern wcwidth module for GNU Guile.

Usage:
    python3 generate_wcwidth.py [--output wcwidth.scm] [--offline EastAsianWidth.txt]
"""

import argparse
import re
import urllib.request
import sys
from typing import List, Tuple, Dict, Set, Optional

# URLs for Unicode data files
EAST_ASIAN_WIDTH_URL = "https://unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt"
UNICODE_DATA_URL = "https://unicode.org/Public/UCD/latest/ucd/UnicodeData.txt"

class UnicodeRange:
    """Represents a range of Unicode codepoints with their properties."""
    
    def __init__(self, start: int, end: int, width: int):
        self.start = start
        self.end = end
        self.width = width
    
    def __repr__(self):
        if self.start == self.end:
            return f"U+{self.start:04X} -> {self.width}"
        else:
            return f"U+{self.start:04X}..U+{self.end:04X} -> {self.width}"
    
    def to_scheme_pair(self) -> str:
        """Convert to Scheme pair format for lookup tables."""
        return f"( #x{self.start:04X} . #x{self.end:04X} )"

def download_file(url: str) -> str:
    """Download a file from URL and return its contents."""
    print(f"Downloading {url}...")
    try:
        with urllib.request.urlopen(url) as response:
            return response.read().decode('utf-8')
    except Exception as e:
        print(f"Error downloading {url}: {e}")
        sys.exit(1)

def extract_unicode_version(content: str) -> Optional[str]:
    """Extract Unicode version from file header comments."""
    for line in content.split('\n')[:20]:  # Check first 20 lines for version info
        line = line.strip()
        if line.startswith('#'):
            # Look for patterns like "# Version: 15.1.0" or "# Unicode 15.1.0"
            version_match = re.search(r'(?:Version|Unicode)[:\s]+(\d+\.\d+\.\d+)', line, re.IGNORECASE)
            if version_match:
                return version_match.group(1)
            
            # Alternative pattern: "# UnicodeData-15.1.0.txt"
            version_match = re.search(r'(\d+\.\d+\.\d+)', line)
            if version_match and 'Unicode' in line:
                return version_match.group(1)
    
    return None

def parse_codepoint_range(cp_str: str) -> Tuple[int, int]:
    """Parse a codepoint or range string like '1F600' or '1F600..1F64F'."""
    if '..' in cp_str:
        start_str, end_str = cp_str.split('..')
        return int(start_str, 16), int(end_str, 16)
    else:
        cp = int(cp_str, 16)
        return cp, cp

def parse_east_asian_width(content: str) -> Dict[str, List[UnicodeRange]]:
    """Parse EastAsianWidth.txt and return ranges by width category."""
    categories = {
        'F': [],  # Fullwidth
        'H': [],  # Halfwidth  
        'W': [],  # Wide
        'Na': [], # Narrow
        'A': [],  # Ambiguous
        'N': []   # Neutral
    }
    
    for line in content.split('\n'):
        # Remove comments and whitespace
        line = line.split('#')[0].strip()
        if not line:
            continue
            
        # Parse line format: codepoint(s);category
        if ';' not in line:
            continue
            
        cp_part, category = line.split(';', 1)
        cp_part = cp_part.strip()
        category = category.strip()
        
        if category in categories:
            start, end = parse_codepoint_range(cp_part)
            # Convert EAW categories to display widths
            if category in ['F', 'W']:
                width = 2  # Fullwidth and Wide = 2 cells
            else:
                width = 1  # Everything else = 1 cell normally
            categories[category].append(UnicodeRange(start, end, width))
    
    return categories

def parse_unicode_data_for_combining_and_control(content: str) -> Tuple[List[UnicodeRange], List[UnicodeRange], List[UnicodeRange]]:
    """Parse UnicodeData.txt to find combining marks, zero-width characters, and control characters."""
    combining_ranges = []
    zero_width_ranges = []
    control_ranges = []
    
    for line in content.split('\n'):
        line = line.strip()
        if not line:
            continue
            
        fields = line.split(';')
        if len(fields) < 3:
            continue
            
        codepoint_str = fields[0]
        name = fields[1] if len(fields) > 1 else ""
        general_category = fields[2]
        
        cp = int(codepoint_str, 16)
        
        # Combining marks: Mn (nonspacing), Mc (spacing combining), Me (enclosing)
        if general_category in ['Mn', 'Mc', 'Me']:
            combining_ranges.append(UnicodeRange(cp, cp, 0))
        
        # Zero-width characters (by name)
        elif "ZERO WIDTH" in name.upper():
            zero_width_ranges.append(UnicodeRange(cp, cp, 0))
        
        # Control characters: Cc (control), Cf (format)
        elif general_category in ['Cc', 'Cf']:
            control_ranges.append(UnicodeRange(cp, cp, -1))
        
        # Additional format characters that should be treated as control
        elif general_category in ['Cs', 'Co']:  # Surrogates and Private Use
            # These are generally not printable
            control_ranges.append(UnicodeRange(cp, cp, -1))
    
    return combining_ranges, zero_width_ranges, control_ranges

def merge_ranges(ranges: List[UnicodeRange]) -> List[UnicodeRange]:
    """Merge adjacent and overlapping ranges with the same width."""
    if not ranges:
        return []
    
    # Sort by start position
    ranges.sort(key=lambda r: r.start)
    
    merged = [ranges[0]]
    
    for current in ranges[1:]:
        last = merged[-1]
        
        # If ranges are adjacent or overlapping and have same width, merge them
        if (current.start <= last.end + 1 and current.width == last.width):
            merged[-1] = UnicodeRange(last.start, max(last.end, current.end), last.width)
        else:
            merged.append(current)
    
    return merged

def generate_scheme_table(ranges: List[UnicodeRange], table_name: str, target_line_length: int = 70) -> str:
    """Generate Scheme code for a lookup table with optimized formatting."""
    if not ranges:
        return f"(define {table_name} '())"
    
    # Pre-calculate all pairs and their lengths
    pair_data = [(r.to_scheme_pair(), len(r.to_scheme_pair())) for r in ranges]
    
    # Build lines efficiently
    lines = []
    current_line_parts = []
    current_line_length = 0
    indent = '           '  # 11 spaces for alignment
    
    for pair_str, pair_length in pair_data:
        # Check if adding this pair would exceed target length
        space_needed = pair_length + (1 if current_line_parts else 0)  # +1 for space separator
        
        if current_line_length + space_needed > target_line_length and current_line_parts:
            # Finish current line and start new one
            lines.append(indent + ' '.join(current_line_parts))
            current_line_parts = [pair_str]
            current_line_length = pair_length
        else:
            # Add to current line
            current_line_parts.append(pair_str)
            current_line_length += space_needed
    
    # Add final line
    if current_line_parts:
        lines.append(indent + ' '.join(current_line_parts))
    
    # Format the definition
    if len(lines) == 1:
        return f"(define {table_name}\n  '({lines[0].strip()}))"
    else:
        first_line = lines[0].strip()
        remaining_lines = '\n'.join(lines[1:])
        return f"(define {table_name}\n  '({first_line}\n{remaining_lines}))"

def generate_wcwidth_module(eaw_categories: Dict[str, List[UnicodeRange]], 
                          combining_ranges: List[UnicodeRange],
                          zero_width_ranges: List[UnicodeRange],
                          control_ranges: List[UnicodeRange],
                          unicode_version: str) -> str:
    """Generate the complete Guile wcwidth module."""
    
    # Merge ranges by width - combine combining marks and zero-width characters
    width_0_ranges = merge_ranges(combining_ranges + zero_width_ranges)
    width_2_ranges = merge_ranges(eaw_categories['F'] + eaw_categories['W'])
    ambiguous_ranges = merge_ranges(eaw_categories['A'])
    control_merged_ranges = merge_ranges(control_ranges)
    
    # Generate lookup tables
    zero_width_table = generate_scheme_table(width_0_ranges, "zero-width-ranges")
    wide_table = generate_scheme_table(width_2_ranges, "wide-ranges") 
    ambiguous_table = generate_scheme_table(ambiguous_ranges, "ambiguous-ranges")
    control_table = generate_scheme_table(control_merged_ranges, "control-ranges")
    
    return f''';;; wcwidth.scm - Unicode character width calculation
;;;
;;; Generated from Unicode {unicode_version} East Asian Width data
;;; Source: {EAST_ASIAN_WIDTH_URL}
;;; 
;;; This module implements wcwidth() for determining the display width
;;; of Unicode characters in terminal applications.

(define-module (gano wcwidth)
  #:export (wcwidth))

;;; =================================================================
;;; UNICODE LOOKUP TABLES
;;; =================================================================

;; Zero-width characters: combining marks and characters with "ZERO WIDTH" in name
{zero_width_table}

;; Wide characters - East Asian Wide (W) and Fullwidth (F) (width 2)
{wide_table}

;; East Asian Ambiguous characters (width 1 normally, 2 in CJK mode)
{ambiguous_table}

;; Control characters - Cc (control), Cf (format), Cs (surrogate), Co (private) (width -1)
{control_table}

;;; =================================================================
;;; BINARY SEARCH HELPER
;;; =================================================================

(define (bisearch-ranges ucs ranges)
  "Binary search in sorted list of (start . end) ranges"
  (let ((len (length ranges)))
    (if (= len 0)
        #f
        (let loop ((min-idx 0) (max-idx (- len 1)))
          (if (> min-idx max-idx)
              #f
              (let* ((mid-idx (quotient (+ min-idx max-idx) 2))
                     (range (list-ref ranges mid-idx))
                     (start (car range))
                     (end (cdr range)))
                (cond
                  ((< ucs start) (loop min-idx (- mid-idx 1)))
                  ((> ucs end) (loop (+ mid-idx 1) max-idx))
                  (else #t))))))))

;;; =================================================================
;;; MAIN WCWIDTH FUNCTION
;;; =================================================================

(define* (wcwidth x #:optional (cjk #f))
  "Calculate the display width of a Unicode character or string.
  
  Returns:
    - 0 for null character, combining marks, and zero-width characters
    - 1 for most characters
    - 2 for wide characters (CJK ideographs, etc.)
    - -1 for control characters (including Unicode format/control categories)
    - For strings: sum of individual character widths
    - For invalid input: -1
  
  If CJK is true, East Asian Ambiguous characters have width 2 instead of 1."
  
  (cond
    ;; Handle string input - sum widths of individual characters
    ((string? x)
     (let ((total 0)
           (invalid #f))
       (string-for-each
         (lambda (c)
           (unless invalid  ; Only process if we haven't found a control char yet
             (let ((char-width (wcwidth c cjk)))
               (if (< char-width 0)
                   (set! invalid #t)  ; Mark as invalid and stop processing
                   (set! total (+ total char-width))))))
         x)
       (if invalid -1 total)))
    
    ;; Handle character input
    ((char? x)
     (wcwidth (char->integer x) cjk))
    
    ;; Handle integer (Unicode codepoint) input
    ((integer? x)
     (let ((ucs x))
       (cond
         ;; Null character
         ((= ucs 0) 0)
         
         ;; Basic C0 control characters (0x00-0x1F) and DEL (0x7F)
         ;; These are handled first for efficiency (common case)
         ((or (< ucs 32) (= ucs 127)) -1)
         
         ;; Basic C1 control characters (0x80-0x9F)
         ((and (>= ucs #x80) (<= ucs #x9F)) -1)
         
         ;; Unicode control characters (comprehensive check)
         ((bisearch-ranges ucs control-ranges) -1)
         
         ;; Zero-width characters (combining marks + zero-width named chars)
         ((bisearch-ranges ucs zero-width-ranges) 0)
         
         ;; Wide characters (width 2)
         ((bisearch-ranges ucs wide-ranges) 2)
         
         ;; East Asian Ambiguous characters
         ((bisearch-ranges ucs ambiguous-ranges)
          (if cjk 2 1))
         
         ;; All other characters (width 1)
         (else 1))))
    
    ;; Invalid input type
    (else -1)))

;;; =================================================================
;;; STATISTICS AND METADATA
;;; =================================================================

;; Total ranges in lookup tables
(define wcwidth-zero-width-count {len(width_0_ranges)})
(define wcwidth-wide-count {len(width_2_ranges)})  
(define wcwidth-ambiguous-count {len(ambiguous_ranges)})
(define wcwidth-control-count {len(control_merged_ranges)})

;; Unicode version
(define wcwidth-unicode-version "{unicode_version}")

;; Export statistics for debugging
(define (wcwidth-statistics)
  "Return statistics about the wcwidth database"
  `((unicode-version . ,wcwidth-unicode-version)
    (zero-width-ranges . ,wcwidth-zero-width-count)
    (wide-ranges . ,wcwidth-wide-count)
    (ambiguous-ranges . ,wcwidth-ambiguous-count)
    (control-ranges . ,wcwidth-control-count)))
'''

def main():
    parser = argparse.ArgumentParser(
        description="Generate Guile wcwidth module from Unicode data")
    parser.add_argument('--output', '-o', default='wcwidth.scm',
                       help='Output file (default: wcwidth.scm)')
    parser.add_argument('--offline', 
                       help='Use local EastAsianWidth.txt file instead of downloading')
    parser.add_argument('--offline-unicode-data',
                       help='Use local UnicodeData.txt file instead of downloading')
    
    args = parser.parse_args()
    
    # Get East Asian Width data
    if args.offline:
        print(f"Reading EastAsianWidth data from {args.offline}")
        with open(args.offline, 'r', encoding='utf-8') as f:
            eaw_content = f.read()
    else:
        eaw_content = download_file(EAST_ASIAN_WIDTH_URL)
    
    # Get Unicode data for combining marks and control characters
    if args.offline_unicode_data:
        print(f"Reading UnicodeData from {args.offline_unicode_data}")
        with open(args.offline_unicode_data, 'r', encoding='utf-8') as f:
            unicode_data_content = f.read()
    else:
        unicode_data_content = download_file(UNICODE_DATA_URL)
    
    # Extract Unicode version
    unicode_version = (extract_unicode_version(eaw_content) or 
                      extract_unicode_version(unicode_data_content) or 
                      "unknown")
    print(f"Detected Unicode version: {unicode_version}")
    
    print("Parsing East Asian Width data...")
    eaw_categories = parse_east_asian_width(eaw_content)
    
    print("Parsing combining marks and control characters from Unicode data...")
    combining_ranges, zero_width_ranges, control_ranges = parse_unicode_data_for_combining_and_control(unicode_data_content)
    
    print("Generating wcwidth module...")
    module_code = generate_wcwidth_module(eaw_categories, combining_ranges, zero_width_ranges, control_ranges, unicode_version)
    
    print(f"Writing output to {args.output}")
    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(module_code)
    
    print(f"Generated {args.output} successfully!")
    print(f"Statistics:")
    print(f"  - Unicode version: {unicode_version}")
    print(f"  - Combining mark ranges: {len(merge_ranges(combining_ranges))}")
    print(f"  - Zero-width character ranges: {len(merge_ranges(zero_width_ranges))}")
    print(f"  - Total zero-width ranges: {len(merge_ranges(combining_ranges + zero_width_ranges))}")
    print(f"  - Control character ranges: {len(merge_ranges(control_ranges))}")
    print(f"  - Wide character ranges: {len(merge_ranges(eaw_categories['F'] + eaw_categories['W']))}")
    print(f"  - Ambiguous character ranges: {len(merge_ranges(eaw_categories['A']))}")

if __name__ == "__main__":
    main()
