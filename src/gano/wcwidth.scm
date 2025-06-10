;;; wcwidth.scm - Unicode character width calculation
;;;
;;; Generated from Unicode 15.1.0 East Asian Width data
;;; Source: https://unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt
;;; 
;;; This module implements wcwidth() for determining the display width
;;; of Unicode characters in terminal applications.

(define-module (gano wcwidth)
  #:export (wcwidth))

;;; =================================================================
;;; UNICODE LOOKUP TABLES
;;; =================================================================

;; Zero-width characters: combining marks and characters with "ZERO WIDTH" in name
(define zero-width-ranges
  '(( #x0300 . #x036F ) ( #x0483 . #x0489 ) ( #x0591 . #x05BD )
           ( #x05BF . #x05BF ) ( #x05C1 . #x05C2 ) ( #x05C4 . #x05C5 )
           ( #x05C7 . #x05C7 ) ( #x0610 . #x061A ) ( #x064B . #x065F )
           ( #x0670 . #x0670 ) ( #x06D6 . #x06DC ) ( #x06DF . #x06E4 )
           ( #x06E7 . #x06E8 ) ( #x06EA . #x06ED ) ( #x0711 . #x0711 )
           ( #x0730 . #x074A ) ( #x07A6 . #x07B0 ) ( #x07EB . #x07F3 )
           ( #x07FD . #x07FD ) ( #x0816 . #x0819 ) ( #x081B . #x0823 )
           ( #x0825 . #x0827 ) ( #x0829 . #x082D ) ( #x0859 . #x085B )
           ( #x0897 . #x089F ) ( #x08CA . #x08E1 ) ( #x08E3 . #x0903 )
           ( #x093A . #x093C ) ( #x093E . #x094F ) ( #x0951 . #x0957 )
           ( #x0962 . #x0963 ) ( #x0981 . #x0983 ) ( #x09BC . #x09BC )
           ( #x09BE . #x09C4 ) ( #x09C7 . #x09C8 ) ( #x09CB . #x09CD )
           ( #x09D7 . #x09D7 ) ( #x09E2 . #x09E3 ) ( #x09FE . #x09FE )
           ( #x0A01 . #x0A03 ) ( #x0A3C . #x0A3C ) ( #x0A3E . #x0A42 )
           ( #x0A47 . #x0A48 ) ( #x0A4B . #x0A4D ) ( #x0A51 . #x0A51 )
           ( #x0A70 . #x0A71 ) ( #x0A75 . #x0A75 ) ( #x0A81 . #x0A83 )
           ( #x0ABC . #x0ABC ) ( #x0ABE . #x0AC5 ) ( #x0AC7 . #x0AC9 )
           ( #x0ACB . #x0ACD ) ( #x0AE2 . #x0AE3 ) ( #x0AFA . #x0AFF )
           ( #x0B01 . #x0B03 ) ( #x0B3C . #x0B3C ) ( #x0B3E . #x0B44 )
           ( #x0B47 . #x0B48 ) ( #x0B4B . #x0B4D ) ( #x0B55 . #x0B57 )
           ( #x0B62 . #x0B63 ) ( #x0B82 . #x0B82 ) ( #x0BBE . #x0BC2 )
           ( #x0BC6 . #x0BC8 ) ( #x0BCA . #x0BCD ) ( #x0BD7 . #x0BD7 )
           ( #x0C00 . #x0C04 ) ( #x0C3C . #x0C3C ) ( #x0C3E . #x0C44 )
           ( #x0C46 . #x0C48 ) ( #x0C4A . #x0C4D ) ( #x0C55 . #x0C56 )
           ( #x0C62 . #x0C63 ) ( #x0C81 . #x0C83 ) ( #x0CBC . #x0CBC )
           ( #x0CBE . #x0CC4 ) ( #x0CC6 . #x0CC8 ) ( #x0CCA . #x0CCD )
           ( #x0CD5 . #x0CD6 ) ( #x0CE2 . #x0CE3 ) ( #x0CF3 . #x0CF3 )
           ( #x0D00 . #x0D03 ) ( #x0D3B . #x0D3C ) ( #x0D3E . #x0D44 )
           ( #x0D46 . #x0D48 ) ( #x0D4A . #x0D4D ) ( #x0D57 . #x0D57 )
           ( #x0D62 . #x0D63 ) ( #x0D81 . #x0D83 ) ( #x0DCA . #x0DCA )
           ( #x0DCF . #x0DD4 ) ( #x0DD6 . #x0DD6 ) ( #x0DD8 . #x0DDF )
           ( #x0DF2 . #x0DF3 ) ( #x0E31 . #x0E31 ) ( #x0E34 . #x0E3A )
           ( #x0E47 . #x0E4E ) ( #x0EB1 . #x0EB1 ) ( #x0EB4 . #x0EBC )
           ( #x0EC8 . #x0ECE ) ( #x0F18 . #x0F19 ) ( #x0F35 . #x0F35 )
           ( #x0F37 . #x0F37 ) ( #x0F39 . #x0F39 ) ( #x0F3E . #x0F3F )
           ( #x0F71 . #x0F84 ) ( #x0F86 . #x0F87 ) ( #x0F8D . #x0F97 )
           ( #x0F99 . #x0FBC ) ( #x0FC6 . #x0FC6 ) ( #x102B . #x103E )
           ( #x1056 . #x1059 ) ( #x105E . #x1060 ) ( #x1062 . #x1064 )
           ( #x1067 . #x106D ) ( #x1071 . #x1074 ) ( #x1082 . #x108D )
           ( #x108F . #x108F ) ( #x109A . #x109D ) ( #x135D . #x135F )
           ( #x1712 . #x1715 ) ( #x1732 . #x1734 ) ( #x1752 . #x1753 )
           ( #x1772 . #x1773 ) ( #x17B4 . #x17D3 ) ( #x17DD . #x17DD )
           ( #x180B . #x180D ) ( #x180F . #x180F ) ( #x1885 . #x1886 )
           ( #x18A9 . #x18A9 ) ( #x1920 . #x192B ) ( #x1930 . #x193B )
           ( #x1A17 . #x1A1B ) ( #x1A55 . #x1A5E ) ( #x1A60 . #x1A7C )
           ( #x1A7F . #x1A7F ) ( #x1AB0 . #x1ACE ) ( #x1B00 . #x1B04 )
           ( #x1B34 . #x1B44 ) ( #x1B6B . #x1B73 ) ( #x1B80 . #x1B82 )
           ( #x1BA1 . #x1BAD ) ( #x1BE6 . #x1BF3 ) ( #x1C24 . #x1C37 )
           ( #x1CD0 . #x1CD2 ) ( #x1CD4 . #x1CE8 ) ( #x1CED . #x1CED )
           ( #x1CF4 . #x1CF4 ) ( #x1CF7 . #x1CF9 ) ( #x1DC0 . #x1DFF )
           ( #x200B . #x200D ) ( #x20D0 . #x20F0 ) ( #x2CEF . #x2CF1 )
           ( #x2D7F . #x2D7F ) ( #x2DE0 . #x2DFF ) ( #x302A . #x302F )
           ( #x3099 . #x309A ) ( #xA66F . #xA672 ) ( #xA674 . #xA67D )
           ( #xA69E . #xA69F ) ( #xA6F0 . #xA6F1 ) ( #xA802 . #xA802 )
           ( #xA806 . #xA806 ) ( #xA80B . #xA80B ) ( #xA823 . #xA827 )
           ( #xA82C . #xA82C ) ( #xA880 . #xA881 ) ( #xA8B4 . #xA8C5 )
           ( #xA8E0 . #xA8F1 ) ( #xA8FF . #xA8FF ) ( #xA926 . #xA92D )
           ( #xA947 . #xA953 ) ( #xA980 . #xA983 ) ( #xA9B3 . #xA9C0 )
           ( #xA9E5 . #xA9E5 ) ( #xAA29 . #xAA36 ) ( #xAA43 . #xAA43 )
           ( #xAA4C . #xAA4D ) ( #xAA7B . #xAA7D ) ( #xAAB0 . #xAAB0 )
           ( #xAAB2 . #xAAB4 ) ( #xAAB7 . #xAAB8 ) ( #xAABE . #xAABF )
           ( #xAAC1 . #xAAC1 ) ( #xAAEB . #xAAEF ) ( #xAAF5 . #xAAF6 )
           ( #xABE3 . #xABEA ) ( #xABEC . #xABED ) ( #xFB1E . #xFB1E )
           ( #xFE00 . #xFE0F ) ( #xFE20 . #xFE2F ) ( #xFEFF . #xFEFF )
           ( #x101FD . #x101FD ) ( #x102E0 . #x102E0 ) ( #x10376 . #x1037A )
           ( #x10A01 . #x10A03 ) ( #x10A05 . #x10A06 ) ( #x10A0C . #x10A0F )
           ( #x10A38 . #x10A3A ) ( #x10A3F . #x10A3F ) ( #x10AE5 . #x10AE6 )
           ( #x10D24 . #x10D27 ) ( #x10D69 . #x10D6D ) ( #x10EAB . #x10EAC )
           ( #x10EFC . #x10EFF ) ( #x10F46 . #x10F50 ) ( #x10F82 . #x10F85 )
           ( #x11000 . #x11002 ) ( #x11038 . #x11046 ) ( #x11070 . #x11070 )
           ( #x11073 . #x11074 ) ( #x1107F . #x11082 ) ( #x110B0 . #x110BA )
           ( #x110C2 . #x110C2 ) ( #x11100 . #x11102 ) ( #x11127 . #x11134 )
           ( #x11145 . #x11146 ) ( #x11173 . #x11173 ) ( #x11180 . #x11182 )
           ( #x111B3 . #x111C0 ) ( #x111C9 . #x111CC ) ( #x111CE . #x111CF )
           ( #x1122C . #x11237 ) ( #x1123E . #x1123E ) ( #x11241 . #x11241 )
           ( #x112DF . #x112EA ) ( #x11300 . #x11303 ) ( #x1133B . #x1133C )
           ( #x1133E . #x11344 ) ( #x11347 . #x11348 ) ( #x1134B . #x1134D )
           ( #x11357 . #x11357 ) ( #x11362 . #x11363 ) ( #x11366 . #x1136C )
           ( #x11370 . #x11374 ) ( #x113B8 . #x113C0 ) ( #x113C2 . #x113C2 )
           ( #x113C5 . #x113C5 ) ( #x113C7 . #x113CA ) ( #x113CC . #x113D0 )
           ( #x113D2 . #x113D2 ) ( #x113E1 . #x113E2 ) ( #x11435 . #x11446 )
           ( #x1145E . #x1145E ) ( #x114B0 . #x114C3 ) ( #x115AF . #x115B5 )
           ( #x115B8 . #x115C0 ) ( #x115DC . #x115DD ) ( #x11630 . #x11640 )
           ( #x116AB . #x116B7 ) ( #x1171D . #x1172B ) ( #x1182C . #x1183A )
           ( #x11930 . #x11935 ) ( #x11937 . #x11938 ) ( #x1193B . #x1193E )
           ( #x11940 . #x11940 ) ( #x11942 . #x11943 ) ( #x119D1 . #x119D7 )
           ( #x119DA . #x119E0 ) ( #x119E4 . #x119E4 ) ( #x11A01 . #x11A0A )
           ( #x11A33 . #x11A39 ) ( #x11A3B . #x11A3E ) ( #x11A47 . #x11A47 )
           ( #x11A51 . #x11A5B ) ( #x11A8A . #x11A99 ) ( #x11C2F . #x11C36 )
           ( #x11C38 . #x11C3F ) ( #x11C92 . #x11CA7 ) ( #x11CA9 . #x11CB6 )
           ( #x11D31 . #x11D36 ) ( #x11D3A . #x11D3A ) ( #x11D3C . #x11D3D )
           ( #x11D3F . #x11D45 ) ( #x11D47 . #x11D47 ) ( #x11D8A . #x11D8E )
           ( #x11D90 . #x11D91 ) ( #x11D93 . #x11D97 ) ( #x11EF3 . #x11EF6 )
           ( #x11F00 . #x11F01 ) ( #x11F03 . #x11F03 ) ( #x11F34 . #x11F3A )
           ( #x11F3E . #x11F42 ) ( #x11F5A . #x11F5A ) ( #x13440 . #x13440 )
           ( #x13447 . #x13455 ) ( #x1611E . #x1612F ) ( #x16AF0 . #x16AF4 )
           ( #x16B30 . #x16B36 ) ( #x16F4F . #x16F4F ) ( #x16F51 . #x16F87 )
           ( #x16F8F . #x16F92 ) ( #x16FE4 . #x16FE4 ) ( #x16FF0 . #x16FF1 )
           ( #x1BC9D . #x1BC9E ) ( #x1CF00 . #x1CF2D ) ( #x1CF30 . #x1CF46 )
           ( #x1D165 . #x1D169 ) ( #x1D16D . #x1D172 ) ( #x1D17B . #x1D182 )
           ( #x1D185 . #x1D18B ) ( #x1D1AA . #x1D1AD ) ( #x1D242 . #x1D244 )
           ( #x1DA00 . #x1DA36 ) ( #x1DA3B . #x1DA6C ) ( #x1DA75 . #x1DA75 )
           ( #x1DA84 . #x1DA84 ) ( #x1DA9B . #x1DA9F ) ( #x1DAA1 . #x1DAAF )
           ( #x1E000 . #x1E006 ) ( #x1E008 . #x1E018 ) ( #x1E01B . #x1E021 )
           ( #x1E023 . #x1E024 ) ( #x1E026 . #x1E02A ) ( #x1E08F . #x1E08F )
           ( #x1E130 . #x1E136 ) ( #x1E2AE . #x1E2AE ) ( #x1E2EC . #x1E2EF )
           ( #x1E4EC . #x1E4EF ) ( #x1E5EE . #x1E5EF ) ( #x1E8D0 . #x1E8D6 )
           ( #x1E944 . #x1E94A ) ( #xE0100 . #xE01EF )))

;; Wide characters - East Asian Wide (W) and Fullwidth (F) (width 2)
(define wide-ranges
  '(( #x1100 . #x115F ) ( #x231A . #x231B ) ( #x2329 . #x232A )
           ( #x23E9 . #x23EC ) ( #x23F0 . #x23F0 ) ( #x23F3 . #x23F3 )
           ( #x25FD . #x25FE ) ( #x2614 . #x2615 ) ( #x2630 . #x2637 )
           ( #x2648 . #x2653 ) ( #x267F . #x267F ) ( #x268A . #x268F )
           ( #x2693 . #x2693 ) ( #x26A1 . #x26A1 ) ( #x26AA . #x26AB )
           ( #x26BD . #x26BE ) ( #x26C4 . #x26C5 ) ( #x26CE . #x26CE )
           ( #x26D4 . #x26D4 ) ( #x26EA . #x26EA ) ( #x26F2 . #x26F3 )
           ( #x26F5 . #x26F5 ) ( #x26FA . #x26FA ) ( #x26FD . #x26FD )
           ( #x2705 . #x2705 ) ( #x270A . #x270B ) ( #x2728 . #x2728 )
           ( #x274C . #x274C ) ( #x274E . #x274E ) ( #x2753 . #x2755 )
           ( #x2757 . #x2757 ) ( #x2795 . #x2797 ) ( #x27B0 . #x27B0 )
           ( #x27BF . #x27BF ) ( #x2B1B . #x2B1C ) ( #x2B50 . #x2B50 )
           ( #x2B55 . #x2B55 ) ( #x2E80 . #x2E99 ) ( #x2E9B . #x2EF3 )
           ( #x2F00 . #x2FD5 ) ( #x2FF0 . #x303E ) ( #x3041 . #x3096 )
           ( #x3099 . #x30FF ) ( #x3105 . #x312F ) ( #x3131 . #x318E )
           ( #x3190 . #x31E5 ) ( #x31EF . #x321E ) ( #x3220 . #x3247 )
           ( #x3250 . #xA48C ) ( #xA490 . #xA4C6 ) ( #xA960 . #xA97C )
           ( #xAC00 . #xD7A3 ) ( #xF900 . #xFAFF ) ( #xFE10 . #xFE19 )
           ( #xFE30 . #xFE52 ) ( #xFE54 . #xFE66 ) ( #xFE68 . #xFE6B )
           ( #xFF01 . #xFF60 ) ( #xFFE0 . #xFFE6 ) ( #x16FE0 . #x16FE4 )
           ( #x16FF0 . #x16FF1 ) ( #x17000 . #x187F7 ) ( #x18800 . #x18CD5 )
           ( #x18CFF . #x18D08 ) ( #x1AFF0 . #x1AFF3 ) ( #x1AFF5 . #x1AFFB )
           ( #x1AFFD . #x1AFFE ) ( #x1B000 . #x1B122 ) ( #x1B132 . #x1B132 )
           ( #x1B150 . #x1B152 ) ( #x1B155 . #x1B155 ) ( #x1B164 . #x1B167 )
           ( #x1B170 . #x1B2FB ) ( #x1D300 . #x1D356 ) ( #x1D360 . #x1D376 )
           ( #x1F004 . #x1F004 ) ( #x1F0CF . #x1F0CF ) ( #x1F18E . #x1F18E )
           ( #x1F191 . #x1F19A ) ( #x1F200 . #x1F202 ) ( #x1F210 . #x1F23B )
           ( #x1F240 . #x1F248 ) ( #x1F250 . #x1F251 ) ( #x1F260 . #x1F265 )
           ( #x1F300 . #x1F320 ) ( #x1F32D . #x1F335 ) ( #x1F337 . #x1F37C )
           ( #x1F37E . #x1F393 ) ( #x1F3A0 . #x1F3CA ) ( #x1F3CF . #x1F3D3 )
           ( #x1F3E0 . #x1F3F0 ) ( #x1F3F4 . #x1F3F4 ) ( #x1F3F8 . #x1F43E )
           ( #x1F440 . #x1F440 ) ( #x1F442 . #x1F4FC ) ( #x1F4FF . #x1F53D )
           ( #x1F54B . #x1F54E ) ( #x1F550 . #x1F567 ) ( #x1F57A . #x1F57A )
           ( #x1F595 . #x1F596 ) ( #x1F5A4 . #x1F5A4 ) ( #x1F5FB . #x1F64F )
           ( #x1F680 . #x1F6C5 ) ( #x1F6CC . #x1F6CC ) ( #x1F6D0 . #x1F6D2 )
           ( #x1F6D5 . #x1F6D7 ) ( #x1F6DC . #x1F6DF ) ( #x1F6EB . #x1F6EC )
           ( #x1F6F4 . #x1F6FC ) ( #x1F7E0 . #x1F7EB ) ( #x1F7F0 . #x1F7F0 )
           ( #x1F90C . #x1F93A ) ( #x1F93C . #x1F945 ) ( #x1F947 . #x1F9FF )
           ( #x1FA70 . #x1FA7C ) ( #x1FA80 . #x1FA89 ) ( #x1FA8F . #x1FAC6 )
           ( #x1FACE . #x1FADC ) ( #x1FADF . #x1FAE9 ) ( #x1FAF0 . #x1FAF8 )
           ( #x20000 . #x2FFFD ) ( #x30000 . #x3FFFD )))

;; East Asian Ambiguous characters (width 1 normally, 2 in CJK mode)
(define ambiguous-ranges
  '(( #x00A1 . #x00A1 ) ( #x00A4 . #x00A4 ) ( #x00A7 . #x00A8 )
           ( #x00AA . #x00AA ) ( #x00AD . #x00AE ) ( #x00B0 . #x00B4 )
           ( #x00B6 . #x00BA ) ( #x00BC . #x00BF ) ( #x00C6 . #x00C6 )
           ( #x00D0 . #x00D0 ) ( #x00D7 . #x00D8 ) ( #x00DE . #x00E1 )
           ( #x00E6 . #x00E6 ) ( #x00E8 . #x00EA ) ( #x00EC . #x00ED )
           ( #x00F0 . #x00F0 ) ( #x00F2 . #x00F3 ) ( #x00F7 . #x00FA )
           ( #x00FC . #x00FC ) ( #x00FE . #x00FE ) ( #x0101 . #x0101 )
           ( #x0111 . #x0111 ) ( #x0113 . #x0113 ) ( #x011B . #x011B )
           ( #x0126 . #x0127 ) ( #x012B . #x012B ) ( #x0131 . #x0133 )
           ( #x0138 . #x0138 ) ( #x013F . #x0142 ) ( #x0144 . #x0144 )
           ( #x0148 . #x014B ) ( #x014D . #x014D ) ( #x0152 . #x0153 )
           ( #x0166 . #x0167 ) ( #x016B . #x016B ) ( #x01CE . #x01CE )
           ( #x01D0 . #x01D0 ) ( #x01D2 . #x01D2 ) ( #x01D4 . #x01D4 )
           ( #x01D6 . #x01D6 ) ( #x01D8 . #x01D8 ) ( #x01DA . #x01DA )
           ( #x01DC . #x01DC ) ( #x0251 . #x0251 ) ( #x0261 . #x0261 )
           ( #x02C4 . #x02C4 ) ( #x02C7 . #x02C7 ) ( #x02C9 . #x02CB )
           ( #x02CD . #x02CD ) ( #x02D0 . #x02D0 ) ( #x02D8 . #x02DB )
           ( #x02DD . #x02DD ) ( #x02DF . #x02DF ) ( #x0300 . #x036F )
           ( #x0391 . #x03A1 ) ( #x03A3 . #x03A9 ) ( #x03B1 . #x03C1 )
           ( #x03C3 . #x03C9 ) ( #x0401 . #x0401 ) ( #x0410 . #x044F )
           ( #x0451 . #x0451 ) ( #x2010 . #x2010 ) ( #x2013 . #x2016 )
           ( #x2018 . #x2019 ) ( #x201C . #x201D ) ( #x2020 . #x2022 )
           ( #x2024 . #x2027 ) ( #x2030 . #x2030 ) ( #x2032 . #x2033 )
           ( #x2035 . #x2035 ) ( #x203B . #x203B ) ( #x203E . #x203E )
           ( #x2074 . #x2074 ) ( #x207F . #x207F ) ( #x2081 . #x2084 )
           ( #x20AC . #x20AC ) ( #x2103 . #x2103 ) ( #x2105 . #x2105 )
           ( #x2109 . #x2109 ) ( #x2113 . #x2113 ) ( #x2116 . #x2116 )
           ( #x2121 . #x2122 ) ( #x2126 . #x2126 ) ( #x212B . #x212B )
           ( #x2153 . #x2154 ) ( #x215B . #x215E ) ( #x2160 . #x216B )
           ( #x2170 . #x2179 ) ( #x2189 . #x2189 ) ( #x2190 . #x2199 )
           ( #x21B8 . #x21B9 ) ( #x21D2 . #x21D2 ) ( #x21D4 . #x21D4 )
           ( #x21E7 . #x21E7 ) ( #x2200 . #x2200 ) ( #x2202 . #x2203 )
           ( #x2207 . #x2208 ) ( #x220B . #x220B ) ( #x220F . #x220F )
           ( #x2211 . #x2211 ) ( #x2215 . #x2215 ) ( #x221A . #x221A )
           ( #x221D . #x2220 ) ( #x2223 . #x2223 ) ( #x2225 . #x2225 )
           ( #x2227 . #x222C ) ( #x222E . #x222E ) ( #x2234 . #x2237 )
           ( #x223C . #x223D ) ( #x2248 . #x2248 ) ( #x224C . #x224C )
           ( #x2252 . #x2252 ) ( #x2260 . #x2261 ) ( #x2264 . #x2267 )
           ( #x226A . #x226B ) ( #x226E . #x226F ) ( #x2282 . #x2283 )
           ( #x2286 . #x2287 ) ( #x2295 . #x2295 ) ( #x2299 . #x2299 )
           ( #x22A5 . #x22A5 ) ( #x22BF . #x22BF ) ( #x2312 . #x2312 )
           ( #x2460 . #x24E9 ) ( #x24EB . #x254B ) ( #x2550 . #x2573 )
           ( #x2580 . #x258F ) ( #x2592 . #x2595 ) ( #x25A0 . #x25A1 )
           ( #x25A3 . #x25A9 ) ( #x25B2 . #x25B3 ) ( #x25B6 . #x25B7 )
           ( #x25BC . #x25BD ) ( #x25C0 . #x25C1 ) ( #x25C6 . #x25C8 )
           ( #x25CB . #x25CB ) ( #x25CE . #x25D1 ) ( #x25E2 . #x25E5 )
           ( #x25EF . #x25EF ) ( #x2605 . #x2606 ) ( #x2609 . #x2609 )
           ( #x260E . #x260F ) ( #x261C . #x261C ) ( #x261E . #x261E )
           ( #x2640 . #x2640 ) ( #x2642 . #x2642 ) ( #x2660 . #x2661 )
           ( #x2663 . #x2665 ) ( #x2667 . #x266A ) ( #x266C . #x266D )
           ( #x266F . #x266F ) ( #x269E . #x269F ) ( #x26BF . #x26BF )
           ( #x26C6 . #x26CD ) ( #x26CF . #x26D3 ) ( #x26D5 . #x26E1 )
           ( #x26E3 . #x26E3 ) ( #x26E8 . #x26E9 ) ( #x26EB . #x26F1 )
           ( #x26F4 . #x26F4 ) ( #x26F6 . #x26F9 ) ( #x26FB . #x26FC )
           ( #x26FE . #x26FF ) ( #x273D . #x273D ) ( #x2776 . #x277F )
           ( #x2B56 . #x2B59 ) ( #x3248 . #x324F ) ( #xE000 . #xF8FF )
           ( #xFE00 . #xFE0F ) ( #xFFFD . #xFFFD ) ( #x1F100 . #x1F10A )
           ( #x1F110 . #x1F12D ) ( #x1F130 . #x1F169 ) ( #x1F170 . #x1F18D )
           ( #x1F18F . #x1F190 ) ( #x1F19B . #x1F1AC ) ( #xE0100 . #xE01EF )
           ( #xF0000 . #xFFFFD ) ( #x100000 . #x10FFFD )))

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
    - -1 for control characters
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
         
         ;; C0 control characters (0x00-0x1F) and DEL (0x7F)
         ((or (< ucs 32) (= ucs 127)) -1)
         
         ;; C1 control characters (0x80-0x9F)
         ((and (>= ucs #x80) (<= ucs #x9F)) -1)
         
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
(define wcwidth-zero-width-count 323)
(define wcwidth-wide-count 122)  
(define wcwidth-ambiguous-count 179)

;; Unicode version
(define wcwidth-unicode-version "15.1.0")

;; Export statistics for debugging
(define (wcwidth-statistics)
  "Return statistics about the wcwidth database"
  `((unicode-version . ,wcwidth-unicode-version)
    (zero-width-ranges . ,wcwidth-zero-width-count)
    (wide-ranges . ,wcwidth-wide-count)
    (ambiguous-ranges . ,wcwidth-ambiguous-count)))
