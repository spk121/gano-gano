#!/usr/bin/env python3
"""
Generate Scheme get-bidi-class function from Unicode data.

This script reads UnicodeData.txt from the Unicode Consortium to generate
a comprehensive bidi class lookup function for UAX #9 implementation.

Usage:
    python generate_bidi_class.py [UnicodeData.txt] [--fill-gaps MAX_GAP_SIZE]

If no file is specified, the script will attempt to download UnicodeData.txt from unicode.org.

Options:
    --fill-gaps MAX_GAP_SIZE    Fill gaps of unspecified codepoints between ranges
                               of the same bidi class, up to MAX_GAP_SIZE characters.
                               This can significantly reduce table size.
"""

import sys
import urllib.request
import os
import argparse
from typing import Dict, List, Tuple, Set
from collections import defaultdict

def download_unicode_file(filename: str, url: str) -> str:
    """Download Unicode data file if it doesn't exist locally."""
    if os.path.exists(filename):
        print(f"Using existing {filename}")
        return filename
    
    print(f"Downloading {filename} from {url}")
    try:
        urllib.request.urlretrieve(url, filename)
        print(f"Downloaded {filename}")
        return filename
    except Exception as e:
        print(f"Error downloading {filename}: {e}")
        return None

def parse_unicode_data(filename: str) -> Tuple[Dict[int, str], Dict[int, str]]:
    """Parse UnicodeData.txt and return bidi class and names for each codepoint."""
    bidi_classes = {}
    char_names = {}
    
    # Track range definitions
    pending_range = None
    
    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                
            fields = line.split(';')
            if len(fields) < 5:
                continue
                
            codepoint_str = fields[0]
            name = fields[1]
            bidi_class = fields[4]
            
            # Handle ranges (like CJK ranges)
            if '..' in codepoint_str:
                # This is a range definition from a previous line
                continue
            
            try:
                codepoint = int(codepoint_str, 16)
                bidi_classes[codepoint] = bidi_class
                char_names[codepoint] = name
            except ValueError:
                # Skip malformed lines
                continue
            
            # Handle ranges defined with <name, First> and <name, Last>
            if name.endswith(', First>'):
                pending_range = {
                    'start': codepoint,
                    'bidi_class': bidi_class,
                    'name_base': name[:-8]  # Remove ', First>'
                }
            elif name.endswith(', Last>') and pending_range:
                # Complete the range
                start_cp = pending_range['start']
                end_cp = codepoint
                range_bidi_class = pending_range['bidi_class']
                range_name_base = pending_range['name_base']
                
                # Fill in the range
                for cp in range(start_cp, end_cp + 1):
                    bidi_classes[cp] = range_bidi_class
                    # Use descriptive names for range endpoints
                    if cp == start_cp:
                        char_names[cp] = f"{range_name_base}, First"
                    elif cp == end_cp:
                        char_names[cp] = f"{range_name_base}, Last"
                    else:
                        char_names[cp] = range_name_base
                
                pending_range = None
    
    return bidi_classes, char_names

def find_ranges(bidi_classes: Dict[int, str]) -> List[Tuple[int, int, str]]:
    """Find contiguous ranges of characters with the same bidi class."""
    if not bidi_classes:
        return []
    
    # Group by bidi class
    class_groups = defaultdict(list)
    for cp, bidi_class in bidi_classes.items():
        class_groups[bidi_class].append(cp)
    
    # Sort each group and find contiguous ranges
    ranges = []
    for bidi_class, codepoints in class_groups.items():
        codepoints.sort()
        
        # Find contiguous ranges
        range_start = codepoints[0]
        range_end = codepoints[0]
        
        for cp in codepoints[1:]:
            if cp == range_end + 1:
                # Extend current range
                range_end = cp
            else:
                # End current range and start new one
                ranges.append((range_start, range_end, bidi_class))
                range_start = cp
                range_end = cp
        
        # Add final range
        ranges.append((range_start, range_end, bidi_class))
    
    # Sort ranges by start codepoint
    ranges.sort(key=lambda x: x[0])
    return ranges

def optimize_ranges(ranges: List[Tuple[int, int, str]]) -> List[Tuple[int, int, str]]:
    """Optimize ranges by merging small ranges and identifying patterns."""
    optimized = []
    
    for start, end, bidi_class in ranges:
        range_size = end - start + 1
        
        # For very small ranges (1-3 characters), might be better as individual cases
        # For larger ranges, definitely use range checks
        if range_size <= 3 and len(optimized) < 50:  # Limit individual cases
            optimized.append((start, end, bidi_class))
        else:
            optimized.append((start, end, bidi_class))
    
    return optimized

def fill_gaps_in_ranges(ranges: List[Tuple[int, int, str]], max_gap_size: int, 
                       bidi_classes: Dict[int, str], char_names: Dict[int, str]) -> List[Tuple[int, int, str]]:
    """Fill gaps between ranges/codepoints of the same bidi class if gap size <= max_gap_size.
    
    This handles gaps between:
    - Single codepoints and ranges
    - Single codepoints and single codepoints  
    - Ranges and ranges
    - Any combination of the above
    
    Includes safeguards to avoid merging across Unicode block boundaries.
    """
    if max_gap_size <= 0:
        return ranges
    
    def get_unicode_block(codepoint: int) -> int:
        """Get a rough Unicode block identifier to avoid merging across script boundaries."""
        # Use the high bits to identify major Unicode blocks
        # This prevents merging across different scripts/writing systems
        return codepoint >> 8  # Groups by 256-character blocks
    
    def should_merge_segments(seg1_end: int, seg2_start: int, gap_size: int) -> bool:
        """Determine if two segments should be merged based on gap size and Unicode blocks."""
        if gap_size > max_gap_size or gap_size <= 0:
            return False
            
        # Don't merge across different Unicode blocks (different scripts/writing systems)
        block1 = get_unicode_block(seg1_end)
        block2 = get_unicode_block(seg2_start)
        
        if block1 != block2:
            return False
            
        # Additional safety: don't merge if gap is more than 50% of the total span
        # This prevents merging segments that are far apart relative to their size
        total_span = seg2_start - seg1_end + 1
        if gap_size > total_span * 0.5:
            return False
            
        return True
    
    # Group ALL ranges/codepoints by bidi class (treating single codepoints as 1-char ranges)
    class_segments = defaultdict(list)
    for start, end, bidi_class in ranges:
        class_segments[bidi_class].append((start, end))
    
    filled_ranges = []
    gaps_filled = 0
    chars_added = 0
    gaps_skipped = 0
    
    for bidi_class, segment_list in class_segments.items():
        # Sort segments by start position
        segment_list.sort()
        
        if len(segment_list) <= 1:
            # No gaps to fill with single or no segments
            for start, end in segment_list:
                filled_ranges.append((start, end, bidi_class))
            continue
        
        merged = []
        current_start, current_end = segment_list[0]
        
        for next_start, next_end in segment_list[1:]:
            gap_start = current_end + 1
            gap_end = next_start - 1
            gap_size = gap_end - gap_start + 1
            
            if should_merge_segments(current_end, next_start, gap_size):
                # Fill the gap - extend current segment to include next segment
                gap_desc = f"U+{gap_start:04X}" if gap_size == 1 else f"U+{gap_start:04X}..U+{gap_end:04X}"
                current_desc = f"U+{current_start:04X}" if current_start == current_end else f"U+{current_start:04X}..U+{current_end:04X}"
                next_desc = f"U+{next_start:04X}" if next_start == next_end else f"U+{next_start:04X}..U+{next_end:04X}"
                
                print(f"  Filling gap {gap_desc} ({gap_size} chars) "
                      f"between {bidi_class} segments {current_desc} and {next_desc}")
                
                # Add the gap characters to our data structures
                for cp in range(gap_start, gap_end + 1):
                    if cp not in bidi_classes:
                        bidi_classes[cp] = bidi_class
                        char_names[cp] = f"<unspecified-{cp:04X}>"
                
                current_end = next_end
                gaps_filled += 1
                chars_added += gap_size
            else:
                # Gap too large or crosses block boundary, keep segments separate
                if 0 < gap_size <= max_gap_size:
                    block1 = get_unicode_block(current_end)
                    block2 = get_unicode_block(next_start)
                    if block1 != block2:
                        print(f"  Skipping gap U+{gap_start:04X}..U+{gap_end:04X} ({gap_size} chars) "
                              f"- crosses Unicode block boundary (U+{block1:02X}xx -> U+{block2:02X}xx)")
                        gaps_skipped += 1
                
                merged.append((current_start, current_end))
                current_start, current_end = next_start, next_end
        
        # Add final segment
        merged.append((current_start, current_end))
        
        # Add to filled_ranges
        for start, end in merged:
            filled_ranges.append((start, end, bidi_class))
    
    if gaps_filled > 0 or gaps_skipped > 0:
        print(f"  Filled {gaps_filled} gaps ({chars_added} chars), skipped {gaps_skipped} cross-block gaps")
    
    # Sort by start position
    filled_ranges.sort(key=lambda x: x[0])
    return filled_ranges

def generate_scheme_function(bidi_classes: Dict[int, str], char_names: Dict[int, str], 
                            max_gap_size: int = 0) -> str:
    """Generate the Guile module with get-bidi-class function."""
    
    # Map Unicode bidi classes to our constants
    bidi_class_mapping = {
        'L': 'BC-L',      # Left-to-Right
        'R': 'BC-R',      # Right-to-Left
        'AL': 'BC-AL',    # Arabic Letter
        'EN': 'BC-EN',    # European Number
        'ES': 'BC-ES',    # European Number Separator
        'ET': 'BC-ET',    # European Number Terminator
        'AN': 'BC-AN',    # Arabic Number
        'CS': 'BC-CS',    # Common Number Separator
        'NSM': 'BC-NSM',  # Nonspacing Mark
        'BN': 'BC-BN',    # Boundary Neutral
        'B': 'BC-B',      # Paragraph Separator
        'S': 'BC-S',      # Segment Separator
        'WS': 'BC-WS',    # Whitespace
        'ON': 'BC-ON',    # Other Neutrals
        'LRE': 'BC-LRE',  # Left-to-Right Embedding
        'LRO': 'BC-LRO',  # Left-to-Right Override
        'RLE': 'BC-RLE',  # Right-to-Left Embedding
        'RLO': 'BC-RLO',  # Right-to-Left Override
        'PDF': 'BC-PDF',  # Pop Directional Formatting
        'LRI': 'BC-LRI',  # Left-to-Right Isolate
        'RLI': 'BC-RLI',  # Right-to-Left Isolate
        'FSI': 'BC-FSI',  # First Strong Isolate
        'PDI': 'BC-PDI',  # Pop Directional Isolate
    }
    
    # Get ranges for optimization
    ranges = find_ranges(bidi_classes)
    
    # Fill gaps if requested
    if max_gap_size > 0:
        print(f"Filling gaps of up to {max_gap_size} characters...")
        ranges = fill_gaps_in_ranges(ranges, max_gap_size, bidi_classes, char_names)
        # Regenerate ranges after gap filling
        ranges = find_ranges(bidi_classes)
    
    ranges = optimize_ranges(ranges)
    
    lines = []
    
    # Module header
    lines.append(";;; Automatically generated bidi class function from Unicode data")
    lines.append(";;; Generated by generate_bidi_class.py")
    lines.append(";;; Based on Unicode Standard Annex #9")
    if max_gap_size > 0:
        lines.append(f";;; Gap filling enabled: max gap size = {max_gap_size}")
    lines.append("")
    lines.append("(define-module (gano bidi-class)")
    lines.append("  #:export (get-bidi-class")
    
    # Export all bidi class constants
    constants = sorted(set(bidi_class_mapping.values()))
    for const in constants:
        lines.append(f"            {const}")
    
    lines.append("))")
    lines.append("")
    
    # Define bidi class constants
    lines.append(";; Bidirectional class constants")
    bidi_descriptions = {
        'BC-L': 'Left-to-Right',
        'BC-R': 'Right-to-Left',
        'BC-AL': 'Arabic Letter',
        'BC-EN': 'European Number',
        'BC-ES': 'European Number Separator',
        'BC-ET': 'European Number Terminator',
        'BC-AN': 'Arabic Number',
        'BC-CS': 'Common Number Separator',
        'BC-NSM': 'Nonspacing Mark',
        'BC-BN': 'Boundary Neutral',
        'BC-B': 'Paragraph Separator',
        'BC-S': 'Segment Separator',
        'BC-WS': 'Whitespace',
        'BC-ON': 'Other Neutrals',
        'BC-LRE': 'Left-to-Right Embedding',
        'BC-LRO': 'Left-to-Right Override',
        'BC-RLE': 'Right-to-Left Embedding',
        'BC-RLO': 'Right-to-Left Override',
        'BC-PDF': 'Pop Directional Formatting',
        'BC-LRI': 'Left-to-Right Isolate',
        'BC-RLI': 'Right-to-Left Isolate',
        'BC-FSI': 'First Strong Isolate',
        'BC-PDI': 'Pop Directional Isolate'
    }
    
    for const in constants:
        desc = bidi_descriptions.get(const, const)
        lines.append(f"(define {const} '{const})  ; {desc}")
    
    lines.append("")
    
    # Generate the function
    lines.append("(define (get-bidi-class char)")
    lines.append('  "Get the bidirectional class of a Unicode character"')
    lines.append("  (let ([cp (char->integer char)])")
    lines.append("    (cond")
    
    # Priority order for bidi classes (most important first)
    priority_classes = [
        'LRE', 'RLE', 'PDF', 'LRO', 'RLO',  # Explicit formatting (highest priority)
        'LRI', 'RLI', 'FSI', 'PDI',         # Isolate formatting
        'B', 'S',                           # Separators
        'L', 'R', 'AL',                     # Strong types
        'EN', 'AN',                         # Numbers
        'ES', 'ET', 'CS',                   # Number-related
        'NSM',                              # Combining marks
        'WS',                               # Whitespace
        'BN',                               # Boundary neutral
        'ON'                                # Other neutrals (default)
    ]
    
    # Add missing classes that might exist in the data
    all_classes = set(bidi_classes.values())
    for cls in all_classes:
        if cls not in priority_classes:
            priority_classes.append(cls)
    
    def format_codepoint(cp: int) -> str:
        """Format codepoint as hex."""
        return f"#x{cp:04X}"
    
    def get_char_comment(cp: int) -> str:
        """Get comment for character using official Unicode name."""
        name = char_names.get(cp, f"U+{cp:04X}")
        # Clean up the name for better readability in comments
        if name.startswith('<') and name.endswith('>'):
            # Handle control characters and special names
            return name[1:-1]  # Remove angle brackets
        return name
    
    def format_range_comment(start: int, end: int) -> str:
        """Format comment for a range of characters."""
        start_name = char_names.get(start, f"U+{start:04X}")
        end_name = char_names.get(end, f"U+{end:04X}")
        
        # Clean up names
        if start_name.startswith('<') and start_name.endswith('>'):
            start_name = start_name[1:-1]
        if end_name.startswith('<') and end_name.endswith('>'):
            end_name = end_name[1:-1]
        
        # Special handling for CJK ranges and other "First/Last" ranges
        if start_name.endswith(', First') and end_name.endswith(', Last'):
            base_name = start_name[:-7]  # Remove ', First'
            return base_name
        elif start_name.endswith(', First'):
            return start_name[:-7]  # Just the base name
        elif end_name.endswith(', Last'):
            return end_name[:-6]   # Just the base name
        else:
            return f"{start_name} .. {end_name}"
    
    # Process each bidi class
    for bidi_class in priority_classes:
        if bidi_class not in bidi_class_mapping:
            continue
            
        scheme_const = bidi_class_mapping[bidi_class]
        
        # Find all ranges for this bidi class
        class_ranges = [r for r in ranges if r[2] == bidi_class]
        
        if not class_ranges:
            continue
        
        # Create comment
        class_comments = {
            'LRE': 'Left-to-Right Embedding',
            'RLE': 'Right-to-Left Embedding', 
            'PDF': 'Pop Directional Formatting',
            'LRO': 'Left-to-Right Override',
            'RLO': 'Right-to-Left Override',
            'LRI': 'Left-to-Right Isolate',
            'RLI': 'Right-to-Left Isolate',
            'FSI': 'First Strong Isolate', 
            'PDI': 'Pop Directional Isolate',
            'B': 'Paragraph Separator',
            'S': 'Segment Separator',
            'L': 'Left-to-Right',
            'R': 'Right-to-Left',
            'AL': 'Arabic Letter',
            'EN': 'European Number',
            'AN': 'Arabic Number',
            'ES': 'European Number Separator',
            'ET': 'European Number Terminator',
            'CS': 'Common Number Separator',
            'NSM': 'Nonspacing Mark',
            'WS': 'Whitespace',
            'BN': 'Boundary Neutral',
            'ON': 'Other Neutrals'
        }
        
        comment = class_comments.get(bidi_class, bidi_class)
        lines.append(f"      ;;;;;;;;;;")
        lines.append(f"      ;; {comment}")
        
        # Separate single characters from ranges
        single_chars = []
        multi_ranges = []
        
        for start, end, _ in class_ranges:
            if start == end:
                single_chars.append(start)
            else:
                multi_ranges.append((start, end))
        
        # Sort everything by codepoint
        single_chars.sort()
        multi_ranges.sort()
        
        # Add comments for all items
        for cp in single_chars:
            char_comment = get_char_comment(cp)
            lines.append(f"      ;; U+{cp:04X}  {char_comment}")
        
        for start, end in multi_ranges:
            range_comment = format_range_comment(start, end)
            lines.append(f"      ;; U+{start:04X}..U+{end:04X}  {range_comment}")
        
        # Build conditions
        conditions = []
        
        # Add single character conditions
        if len(single_chars) == 1:
            conditions.append(f"(= cp {format_codepoint(single_chars[0])})")
        elif len(single_chars) > 1:
            if len(single_chars) <= 20:  # Use memq for reasonable numbers
                hex_values = [format_codepoint(cp) for cp in single_chars]
                conditions.append(f"(memq cp '({' '.join(hex_values)}))")
            else:
                # For very large lists, break into smaller memq calls
                chunk_size = 20
                for i in range(0, len(single_chars), chunk_size):
                    chunk = single_chars[i:i+chunk_size]
                    hex_values = [format_codepoint(cp) for cp in chunk]
                    conditions.append(f"(memq cp '({' '.join(hex_values)}))")
        
        # Add range conditions
        for start, end in multi_ranges:
            conditions.append(f"(<= {format_codepoint(start)} cp {format_codepoint(end)})")
        
        # Output the final condition
        if len(conditions) == 1:
            lines.append(f"      [{conditions[0]} {scheme_const}]")
        else:
            lines.append(f"      [(or")
            for condition in conditions:
                lines.append(f"        {condition}")
            lines.append(f"       ) {scheme_const}]")
    
    # Default case
    lines.append("      ;; Default to Other Neutrals")
    lines.append("      [else BC-ON])))")
    
    return '\n'.join(lines)

def main():
    """Main function to generate bidi class function."""
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(
        description='Generate Scheme get-bidi-class function from Unicode data',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python generate_bidi_class.py
  python generate_bidi_class.py UnicodeData.txt
  python generate_bidi_class.py --fill-gaps 10
  python generate_bidi_class.py UnicodeData.txt --fill-gaps 5
        """
    )
    
    parser.add_argument('unicode_file', nargs='?', default='UnicodeData.txt',
                       help='Path to UnicodeData.txt file (default: UnicodeData.txt)')
    parser.add_argument('--fill-gaps', type=int, metavar='MAX_GAP_SIZE',
                       help='Fill gaps of unspecified codepoints between ranges of the same bidi class')
    
    args = parser.parse_args()
    
    unicode_data_file = args.unicode_file
    max_gap_size = args.fill_gaps or 0
    
    # Download file if needed
    unicode_data_url = "https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt"
    
    if not os.path.exists(unicode_data_file):
        unicode_data_file = download_unicode_file(unicode_data_file, unicode_data_url)
        if not unicode_data_file:
            print("Failed to obtain UnicodeData.txt")
            sys.exit(1)
    
    print("Parsing Unicode data...")
    bidi_classes, char_names = parse_unicode_data(unicode_data_file)
    print(f"Loaded bidi classes for {len(bidi_classes)} characters")
    
    # Count characters by bidi class
    class_counts = defaultdict(int)
    for bidi_class in bidi_classes.values():
        class_counts[bidi_class] += 1
    
    print("\nBidi class distribution:")
    for bidi_class, count in sorted(class_counts.items()):
        print(f"  {bidi_class}: {count} characters")
    
    # Generate Scheme function
    print("\nGenerating Guile module...")
    scheme_code = generate_scheme_function(bidi_classes, char_names, max_gap_size)
    
    # Show final counts after gap filling
    if max_gap_size > 0:
        final_class_counts = defaultdict(int)
        for bidi_class in bidi_classes.values():
            final_class_counts[bidi_class] += 1
        
        print(f"\nFinal bidi class distribution after gap filling:")
        for bidi_class, count in sorted(final_class_counts.items()):
            original_count = class_counts[bidi_class]
            if count != original_count:
                print(f"  {bidi_class}: {count} characters (+{count - original_count})")
            else:
                print(f"  {bidi_class}: {count} characters")
    
    # Output results
    output_file = "bidi-class.scm"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(scheme_code)
        f.write("\n")
    
    print(f"\nGenerated Guile module saved to {output_file}")
    
    # Also print to stdout
    print("\n" + "="*60)
    print("Generated Guile module code:")
    print("="*60)
    print(scheme_code)

if __name__ == "__main__":
    main()
