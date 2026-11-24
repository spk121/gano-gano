#!/usr/bin/env python3
"""
Generate Scheme bracket-pairs definition from Unicode data.

This script reads UnicodeData.txt and optionally BidiBrackets.txt from the Unicode
Consortium to generate a comprehensive list of bracket pairs for use in the 
UAX #9 bidirectional algorithm implementation.

Usage:
    python generate_bracket_pairs.py [UnicodeData.txt] [BidiBrackets.txt]

If no files are specified, the script will attempt to download them from unicode.org.
"""

import sys
import re
import urllib.request
import os
from typing import Dict, List, Tuple, Optional

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

def parse_unicode_data(filename: str) -> Dict[int, Dict[str, str]]:
    """Parse UnicodeData.txt and return character information."""
    chars = {}
    
    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                
            fields = line.split(';')
            if len(fields) < 15:
                continue
                
            codepoint = int(fields[0], 16)
            name = fields[1]
            general_category = fields[2]
            bidi_class = fields[4]
            decomposition = fields[5]
            bidi_mirrored = fields[9]
            
            chars[codepoint] = {
                'name': name,
                'category': general_category,
                'bidi_class': bidi_class,
                'bidi_mirrored': bidi_mirrored == 'Y',
                'decomposition': decomposition
            }
    
    return chars

def parse_bidi_brackets(filename: str) -> Dict[int, int]:
    """Parse BidiBrackets.txt and return bracket pairing information."""
    bracket_pairs = {}
    
    if not os.path.exists(filename):
        print(f"BidiBrackets.txt not found, using heuristic matching")
        return bracket_pairs
    
    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                
            # Format: codepoint; paired_codepoint; bracket_type
            parts = line.split('#')[0].strip().split(';')
            if len(parts) < 3:
                continue
                
            try:
                codepoint = int(parts[0].strip(), 16)
                paired_codepoint = int(parts[1].strip(), 16)
                bracket_type = parts[2].strip()
                
                bracket_pairs[codepoint] = paired_codepoint
            except ValueError:
                continue
    
    return bracket_pairs

def validate_bracket_pair(open_cp: int, close_cp: int, chars: Dict[int, Dict[str, str]]) -> bool:
    """Validate that two characters form a valid bracket pair."""
    if open_cp not in chars or close_cp not in chars:
        return False
    
    open_info = chars[open_cp]
    close_info = chars[close_cp]
    
    # Check general categories - opening should be Ps, closing should be Pe
    if open_info['category'] != 'Ps' or close_info['category'] != 'Pe':
        return False
    
    # Both should have compatible bidi classes (typically ON - Other Neutral)
    # Some brackets might have different bidi classes but they should be reasonable
    valid_bidi_classes = {'ON', 'L', 'R', 'AL', 'AN', 'EN'}
    if (open_info['bidi_class'] not in valid_bidi_classes or 
        close_info['bidi_class'] not in valid_bidi_classes):
        return False
    
    return True

def find_bracket_pairs_heuristic(chars: Dict[int, Dict[str, str]]) -> List[Tuple[int, int, str]]:
    """Find bracket pairs using enhanced heuristic name matching."""
    pairs = []
    opening_brackets = {}
    
    # First pass: collect opening brackets
    for codepoint, info in chars.items():
        if info['category'] == 'Ps':  # Punctuation, open
            name = info['name']
            opening_brackets[codepoint] = name
    
    # Second pass: find matching closing brackets
    for codepoint, info in chars.items():
        if info['category'] == 'Pe':  # Punctuation, close
            close_name = info['name']
            
            # Try to find matching opening bracket
            for open_cp, open_name in opening_brackets.items():
                if is_matching_pair(open_name, close_name):
                    # Validate the pair before adding
                    if validate_bracket_pair(open_cp, codepoint, chars):
                        pairs.append((open_cp, codepoint, f"{open_name} / {close_name}"))
                        break
    
    return pairs

def is_matching_pair(open_name: str, close_name: str) -> bool:
    """Determine if two bracket names form a matching pair with enhanced patterns."""
    
    # Enhanced patterns for bracket names
    patterns = [
        # Standard pattern: LEFT X / RIGHT X
        (r'^LEFT (.+)$', r'^RIGHT \1$'),
        # Mathematical pattern: LEFT X / RIGHT X  
        (r'^MATHEMATICAL LEFT (.+)$', r'^MATHEMATICAL RIGHT \1$'),
        # CJK and other language patterns
        (r'^LEFT (.+ BRACKET)$', r'^RIGHT \1$'),
        (r'^LEFT (.+ PARENTHESIS)$', r'^RIGHT \1$'),
        (r'^LEFT (.+ BRACE)$', r'^RIGHT \1$'),
        # Fullwidth patterns
        (r'^FULLWIDTH LEFT (.+)$', r'^FULLWIDTH RIGHT \1$'),
        # Small/medium/large variants
        (r'^SMALL LEFT (.+)$', r'^SMALL RIGHT \1$'),
        (r'^MEDIUM LEFT (.+)$', r'^MEDIUM RIGHT \1$'),
        (r'^LARGE LEFT (.+)$', r'^LARGE RIGHT \1$'),
        # Ornate patterns
        (r'^ORNATE LEFT (.+)$', r'^ORNATE RIGHT \1$'),
        # Heavy patterns
        (r'^HEAVY LEFT (.+)$', r'^HEAVY RIGHT \1$'),
        # Light patterns  
        (r'^LIGHT LEFT (.+)$', r'^LIGHT RIGHT \1$'),
        # Double patterns
        (r'^DOUBLE LEFT (.+)$', r'^DOUBLE RIGHT \1$'),
        # White patterns
        (r'^WHITE LEFT (.+)$', r'^WHITE RIGHT \1$'),
        # Black patterns
        (r'^BLACK LEFT (.+)$', r'^BLACK RIGHT \1$'),
        # Top/bottom patterns (for some specialized brackets)
        (r'^TOP LEFT (.+)$', r'^TOP RIGHT \1$'),
        (r'^BOTTOM LEFT (.+)$', r'^BOTTOM RIGHT \1$'),
        # Opening/closing patterns (alternative naming)
        (r'^OPENING (.+)$', r'^CLOSING \1$'),
        # Start/end patterns
        (r'^START (.+)$', r'^END \1$'),
    ]
    
    # Test all patterns
    for open_pattern, close_pattern in patterns:
        open_match = re.match(open_pattern, open_name)
        if open_match:
            # Extract the middle part and construct expected closing name
            middle_part = open_match.group(1)
            expected_close = close_pattern.replace(r'\1', middle_part)
            # Remove the regex anchors for comparison
            expected_close = expected_close.replace('^', '').replace('$', '')
            if expected_close == close_name:
                return True
    
    # Enhanced special hardcoded cases
    special_pairs = {
        # Basic ASCII brackets
        'LEFT PARENTHESIS': 'RIGHT PARENTHESIS',
        'LEFT SQUARE BRACKET': 'RIGHT SQUARE BRACKET', 
        'LEFT CURLY BRACKET': 'RIGHT CURLY BRACKET',
        'LESS-THAN SIGN': 'GREATER-THAN SIGN',
        
        # Common mathematical brackets
        'LEFT ANGLE BRACKET': 'RIGHT ANGLE BRACKET',
        'LEFT FLOOR': 'RIGHT FLOOR',
        'LEFT CEILING': 'RIGHT CEILING',
        
        # CJK brackets
        'LEFT CORNER BRACKET': 'RIGHT CORNER BRACKET',
        'LEFT WHITE CORNER BRACKET': 'RIGHT WHITE CORNER BRACKET',
        'LEFT BLACK LENTICULAR BRACKET': 'RIGHT BLACK LENTICULAR BRACKET',
        'LEFT WHITE LENTICULAR BRACKET': 'RIGHT WHITE LENTICULAR BRACKET',
        'LEFT TORTOISE SHELL BRACKET': 'RIGHT TORTOISE SHELL BRACKET',
        'LEFT WHITE TORTOISE SHELL BRACKET': 'RIGHT WHITE TORTOISE SHELL BRACKET',
        
        # Additional mathematical delimiters
        'LEFT VERTICAL BAR': 'RIGHT VERTICAL BAR',
        'LEFT DOUBLE VERTICAL BAR': 'RIGHT DOUBLE VERTICAL BAR',
        
        # Quote-like brackets (sometimes categorized as brackets)
        'LEFT DOUBLE QUOTATION MARK': 'RIGHT DOUBLE QUOTATION MARK',
        'LEFT SINGLE QUOTATION MARK': 'RIGHT SINGLE QUOTATION MARK',
        
        # Specialized technical brackets
        'LEFT-POINTING ANGLE BRACKET': 'RIGHT-POINTING ANGLE BRACKET',
        'MATHEMATICAL LEFT ANGLE BRACKET': 'MATHEMATICAL RIGHT ANGLE BRACKET',
        'MATHEMATICAL LEFT DOUBLE ANGLE BRACKET': 'MATHEMATICAL RIGHT DOUBLE ANGLE BRACKET',
        'MATHEMATICAL LEFT WHITE SQUARE BRACKET': 'MATHEMATICAL RIGHT WHITE SQUARE BRACKET',
        'MATHEMATICAL LEFT FLATTENED PARENTHESIS': 'MATHEMATICAL RIGHT FLATTENED PARENTHESIS',
        
        # Additional variants that might not match patterns
        'PRESENTATION FORM FOR VERTICAL LEFT PARENTHESIS': 'PRESENTATION FORM FOR VERTICAL RIGHT PARENTHESIS',
        'PRESENTATION FORM FOR VERTICAL LEFT CURLY BRACKET': 'PRESENTATION FORM FOR VERTICAL RIGHT CURLY BRACKET',
        'PRESENTATION FORM FOR VERTICAL LEFT SQUARE BRACKET': 'PRESENTATION FORM FOR VERTICAL RIGHT SQUARE BRACKET',
    }
    
    return special_pairs.get(open_name) == close_name

def format_bracket_pairs(pairs: List[Tuple[int, int, str]], chars: Dict[int, Dict[str, str]]) -> str:
    """Format bracket pairs as Guile module code."""
    
    def format_char(codepoint: int) -> str:
        """Format a Unicode codepoint as a Scheme character literal."""
        if codepoint < 128 and chr(codepoint).isprintable() and codepoint not in [ord('\\'), ord('"'), ord('#')]:
            return f"#\\{chr(codepoint)}"
        else:
            return f"#\\x{codepoint:X}"
    
    def get_comment(open_cp: int, close_cp: int) -> str:
        """Generate comment for the bracket pair."""
        open_name = chars[open_cp]['name']
        close_name = chars[close_cp]['name']
        
        # Simplify common names for more readable comments
        simplifications = [
            (r'^(MATHEMATICAL )?LEFT (.+)$', r'\2'),
            (r'^LEFT (.+) BRACKET$', r'\1 BRACKET'),
            (r'^LEFT (.+) PARENTHESIS$', r'\1 PARENTHESIS'),
            (r'^LEFT (.+) BRACE$', r'\1 BRACE'),
            (r'^LEFT (.+)$', r'\1'),
        ]
        
        simplified_name = open_name
        for pattern, replacement in simplifications:
            match = re.match(pattern, open_name)
            if match:
                if r'\2' in replacement and len(match.groups()) >= 2:
                    simplified_name = replacement.replace(r'\2', match.group(2))
                elif r'\1' in replacement and len(match.groups()) >= 1:
                    simplified_name = replacement.replace(r'\1', match.group(1))
                break
        
        return simplified_name
    
    # Sort pairs by codepoint for consistent output
    pairs.sort(key=lambda x: x[0])
    
    lines = []
    
    # Module header
    lines.append(";;; Automatically generated bracket pairs from Unicode data")
    lines.append(";;; Generated by generate_bracket_pairs.py")
    lines.append(";;; Validated bracket pairs with proper general categories")
    lines.append("")
    lines.append("(define-module (gano bracket-pairs)")
    lines.append("  #:export (bracket-pairs))")
    lines.append("")
    
    # Define the bracket-pairs list
    lines.append("(define bracket-pairs")
    lines.append("  '(")
    
    max_pair_length = 0
    formatted_pairs = []
    
    for open_cp, close_cp, _ in pairs:
        open_char = format_char(open_cp)
        close_char = format_char(close_cp)
        pair_str = f"({open_char} . {close_char})"
        comment = get_comment(open_cp, close_cp)
        
        formatted_pairs.append((pair_str, comment))
        max_pair_length = max(max_pair_length, len(pair_str))
    
    # Add formatted pairs with aligned comments
    for i, (pair_str, comment) in enumerate(formatted_pairs):
        padding = " " * (max_pair_length - len(pair_str) + 2)
        suffix = "" if i == len(formatted_pairs) - 1 else ""
        lines.append(f"    {pair_str}{padding}; {comment}{suffix}")
    
    lines.append("))")
    
    return "\n".join(lines)

def main():
    """Main function to generate bracket pairs."""
    
    # Handle command line arguments
    unicode_data_file = sys.argv[1] if len(sys.argv) > 1 else "UnicodeData.txt"
    bidi_brackets_file = sys.argv[2] if len(sys.argv) > 2 else "BidiBrackets.txt"
    
    # Download files if needed
    unicode_data_url = "https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt"
    bidi_brackets_url = "https://www.unicode.org/Public/UCD/latest/ucd/BidiBrackets.txt"
    
    if not os.path.exists(unicode_data_file):
        unicode_data_file = download_unicode_file(unicode_data_file, unicode_data_url)
        if not unicode_data_file:
            print("Failed to obtain UnicodeData.txt")
            sys.exit(1)
    
    if not os.path.exists(bidi_brackets_file):
        bidi_brackets_file = download_unicode_file(bidi_brackets_file, bidi_brackets_url)
        # BidiBrackets.txt is optional, continue without it
    
    print("Parsing Unicode data...")
    chars = parse_unicode_data(unicode_data_file)
    print(f"Loaded {len(chars)} character definitions")
    
    # Try to use official bracket pairs first
    bracket_pairs_dict = {}
    if bidi_brackets_file and os.path.exists(bidi_brackets_file):
        print("Parsing BidiBrackets.txt...")
        bracket_pairs_dict = parse_bidi_brackets(bidi_brackets_file)
        print(f"Found {len(bracket_pairs_dict)} official bracket pairs")
    
    # Find bracket pairs
    if bracket_pairs_dict:
        # Use official bracket pairs with validation
        pairs = []
        valid_pairs = 0
        for open_cp, close_cp in bracket_pairs_dict.items():
            if open_cp in chars and close_cp in chars:
                if validate_bracket_pair(open_cp, close_cp, chars):
                    open_name = chars[open_cp]['name']
                    close_name = chars[close_cp]['name']
                    pairs.append((open_cp, close_cp, f"{open_name} / {close_name}"))
                    valid_pairs += 1
                else:
                    print(f"Warning: Invalid bracket pair found: U+{open_cp:04X} -> U+{close_cp:04X}")
        
        print(f"Validated {valid_pairs}/{len(bracket_pairs_dict)} official bracket pairs")
    else:
        # Use heuristic matching
        print("Using enhanced heuristic bracket pair detection...")
        pairs = find_bracket_pairs_heuristic(chars)
    
    print(f"Found {len(pairs)} valid bracket pairs")
    
    # Generate Scheme code
    scheme_code = format_bracket_pairs(pairs, chars)
    
    # Output results
    output_file = "bracket-pairs.scm"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(scheme_code)
        f.write("\n")
    
    print(f"\nGenerated Guile module saved to {output_file}")
    print(f"Found {len(pairs)} bracket pairs total")
    
    # Also print to stdout
    print("\n" + "="*60)
    print("Generated Guile module code:")
    print("="*60)
    print(scheme_code)

if __name__ == "__main__":
    main()
