(define-module (gano ecma48)
  #:export ()
  )

#|

The <Ecma48> class acts as a 'receiving device' of text and coded control
functions.  It takes input from an INPUT PORT, and stores the text
in a CBuffer.  If it receives any control functions for coded character
sets (as described in Standard ECMA-48) it will try to interpret them.

Upon recipt of <eof> from the input port, or of the control function
<esc> + '[' + {optional '0'} + 'i' -- which is the MEDIA COPY command
to the initiate transfer to the primary auxiliary device -- or the ISO
1745 hangup sequence DLE + EOT, the buffered text will be written out
to the MEDIA OUTPUT PORT.

Some control functions (like CPR cursor position report, or DSR device
status report) expect a response from the terminal.  This script will
print the responses to the RESPONSE OUTPUT PORT.

Also, this receiving device does not interpret of the control strings
opened with APC, DCS, OSC, PM, or SOS. These will be written to the
MESSAGE OUTPUT PORT.

This class also acts like a ISO 1745 slave station, and it will
interpret any ISO 1745 messages it receives.  If a response is
requested, it'll be sent to the RESPONSE OUTPUT PORT.  If an ISO 1745
message is received, it will be written to the MESSAGE OUTPUT PORT.

If the input sends an FNK function key message, it is also forwarded
on to the MESSAGE OUTPUT PORT.

It also takes some callbacks. 

There are two device callbacks that take a single boolean
parameter. If the DEVICE 1 CALLBACK is set, it will receive a call
with #t when a DC1 is received and a #f when DC3 is received.  If the
DEVICE 2 CALLBACK is set, it will respond similarly to DC2 and DC4.

There is an alarm callback which takes no parameters.If the
ALARM_CALLBACK is set, it will be called when an ALARM (aka BEL) is
received.

Similarly, there is an INT Interrupt callback.

The script does not fully conform to the standard.  Many features are
unimplemented.  But to be fair, no one device could adhere to all
parts of the standard.

This 'receiving device' is assumes a notional page of 80 columns, 60
lines, and an infinite number of pages.  But it has no real column
limit, so if the text extends beyond the 80th column, it is not
wrapped or dropped.

The Horizontal tab table is initially, 8, 16, ... 80.

The Vertical tab table is initially 6, 12, ... 60.

Input interpretaton must be set to one of the foolowing modes.
- MODE 1: 7-bit controls. 7-bit US-ASCII characters. All codepage
  commands ignored.
- MODE 2: 7-bit controls. 7-bit characters. SO/SI codepage shift is
  enabled.  A G1 table must be given.
- MODE 3: 7-bit and 8-bit controls. ISO-2022 shifts for codepages
  G0 to G3.  Tables for G1, G2, and G3 must be given.
- MODE 4: 7-bit controls. UTF-8 characters.  All codepage commands ignored.

Furthermore, input interpretation has the following flags - COMPOSE:
handle overstruck characters

Character width is ignored completely.  All codepoints stored in the
CBuffer are assumed to have a presentation width of 1, for now.

All "Selected Areas" and "Qualified Areas" functionality is ignored.
This includes "Protected Areas" and "Guarded Areas".  They don't jive
which this type of communcation mode.  The Guarded Area Transfer
Mode (GATM) is unimplemented. This includes SSA, ESA, DAQ, GATM, SPA,
EPA.

Any invalid sequences sent to the INPUT PORT will cause those bytes to
be ignored and an error to be thrown.

|#

#|

----------------
ECMA-16 Behavior

If an ENQ is received by the INPUT PORT, an ACK will be sent to the
RESPONSE OUTPUT PORT.

If a SYN is sent by the INPUT, a SYN will be sent to the RESPONSE OUTPUT
PORT.

If a ECMA-16 message is received by the INPUT PORT, and ACK will be
sent to the RESPONSE OUTPUT PORT.

If a DLE + EOT is sent by the input port, the class will treat it
as if it were an EOF.

All other parts of ECMA-16 will be unimplemented.

----------------
ECMA-35 Behavior

Maybe I'll get this.  Everyone's moved on to UTF-8, though.

For now, ignore all SI/SO and shifts and such

----------------
ECMA-48 Behavior
|#

;; The line spacing parameters enum type is used
;; by SVS - SVS SELECT LINE SPACING.
(define LINE_SPACING_PARAMETERS
  '((0 "6LPI"      (/ 1.0 6.0))
    (1 "4LPI"      (/ 1.0 4.0))
    (2 "3LPI"      (/ 1.0 3.0))
    (3 "12LPI"     (/ 1.0 12.0))
    (4 "8LPI"      (/ 1.0 8.0))
    (5 "6LP30MM"   (/ (/ 30.0 6.0) 25.4))
    (6 "4LP30MM"   (/ (/ 30.0 4.0) 25.4))
    (7 "3LP30MM"   (/ (/ 30.0 3.0) 25.4))
    (8 "12LP30MM"  (/ (/ 30.0 12.0) 25.4))
    (9 "2LPI"      (/ 1.0 2.0))))

(define-class <Ecma48Buffer> (<CBuffer>)

  (m_AlarmCallback #:init-value #f
		   #:getter get-alarm-callback
		   #:setter set-alarm-callback!)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; ISO 2022 interpretation

  ;; Are we accepting UTF-8?  Are we actually interpreting
  ;; the various shifts and storing G0, G1, G2 and G3
  ;; tables?
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; CONTROL STRINGS

  ;; Control strings such as APC - APPLICATION PROGRAM COMMAND
  ;; and DCS - DEVICE CONTROL STRING are forwarded to
  ;; a message port.  They aren't interpreted by this class.

  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; PRESENTATION COMPONENT
  
  ;; One of 'horizontal or 'vertical.  Determines if the text would be
  ;; horizontal or vertical on the screen when displayed.
  (m_LineOrientation #:init-value 'horizontal)

  ;; One of top-to-bottom, bottom-to-top, left-to-right, or right-to-left.
  ;; top-to-bottom and bottom-to-top are only valid when m_LineOrientation
  ;; is 'vertical, and the other two are 'horizontal.
  (m_LineProgression #:init-value 'top-to-bottom)

  ;; One of 'left-to-right or 'right-to-left if m_LineOrientation is
  ;; 'horizontal.  Else one of 'top-to-bottom or 'bottom-to-top.
  ;; Describes how the sequential order of the character positions are
  ;; visualized.
  (m_CharacterPath #:init-value 'left-to-right)

  ;; The presentation position is the character position that is to
  ;; receive the next character.  So it is the cursor location.

  ;; The line, field, area, and page containing the active
  ;; presentation position are the 'active line', 'active field'
  ;; 'active area', and 'active page' respectively.

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; DATA COMPONENT

  ;; The data component is where the text is stored in logical
  ;; order.  This is mostly handled by the underlying CBuffer.

  ;; There is an 'active data position' which is the data location
  ;; of the cursor.

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; GRAPHIC IMAGE OUTPUT

  ;; The graphic image output is one or more pages of predetermined
  ;; size.  A page had a set number of lines and character positions.
  ;; It has a line spacing and a character spacing.  There are fonts.

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; FORMATOR FUNCTIONS AND EDITOR FUNCTIONS

  ;; There are no selected areas, qualified areas, protected
  ;; areas or guarded areas in this implementation.

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; AUXILIARY I/O DEVICES

  ;; We use the MC - MEDIA COPY command to initiate transmission
  ;; of the text data to a port.

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; TABULATION AND FIELDS

  ;; Tab stops are set.

  ;; Fields are defined as a region that begins at a tab stop
  ;; and ends at the position before the next tab stop.

  ;; Horizontal tabs are one of 'centred, 'leading, 'trailing,
  ;; or 'centered-on-character.

  ;; The vertical and horizontal tab characters themselves are stored
  ;; in the data component, and are rendered in the presetation
  ;; component.

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; MODES

  ;; CRM - CONTROL REPRESENTATION determines if control characters are
  ;; inerpreted at commands or as plain text.  In this implementation
  ;; CRM is always 'control.  Control functions are performed as
  ;; defined.

  ;; DSCM - DEVICE COMPONENT SELECT MODE determines if certain control
  ;; functions are performed by how the characters are presented
  ;; rather than how they are stored.

  ;; ERM - ERASEURE MODE has to do with protected areas, which are
  ;; unimplemented.

  ;; FEAM - FORMAT_EFFECTOR ACTION MODE determines if we store
  ;; formator functions.  Mostly we chose 'execute, which is
  ;; to say that we perform them right away.

  ;; FETM - FORMAT EFFECTOR TRANSFER MODE here is 'exclude because we
  ;; don't send any format effectors to any downstream ports.

  ;; GATM - GUARDED AREA TRANSFER MODE is 'all because we don't
  ;; implementa guarded areas

  ;; GRCM - GRAPHIC RENDITION COMBINATION MODE has to do with SGR

  ;; HEM - CHARACTER EDITING MODE is 'following or 'preceding.
  ;; A character insertion either shifts text logical left or
  ;; logical right.

  ;; IRM - INSERTION REPLACEMENT MODE is 'replace or 'insert.

  ;; KAM - KEYBOARD ACTION MODE is irrelevant here.

  ;; MATM - MULTIPLE AREA TRANSFER MODE is ignored.

  ;; PUM - POSITIONING UNIT MODE

  ;; SATM - SELECTED AREA TRANSFER MODE  is ignored.

  ;; SRM - SEND/RECEIVE MODE is basically 'monitor here.  All commands
  ;; come from a port, so there are no local input facilities.

  ;; SRTM - STATUS REPORT TRANSFER MODE is 'normal.  If you
  ;; want diagnostic information use the logger.

  ;; TSM - TABULATION STOP MODE is probably 'multiple, in that
  ;; there is only one global tab column store.

  ;; TTM - TRANSFER TERMINATION MODE is 'all, but, we don't
  ;; implement this the way it describes.

  ;; VEM - LINE EDITING MODE is either 'following or
  ;; 'preceding, whether lines are pushed forward or
  ;; backward when new lines are inserted or lines are
  ;; deleted.

  ;; ZSM - ZERO DEFAULT MODE

  
  ;; One of the line spacing enum values
  (m_LineSpacing #:init-value 0
		 #:getter get-line-spacing
		 #:setter set-line-spacing!)
  
  (m_ResponsePort #:init-value #f
			#:getter get-response-port
			#:setter set-response-port!)
  
  ;; The SSU enum type for units
  (m_SizeUnit #:init-value 0
	      #:getter get-size-unit
	      #:setter set-size-unit!)

  (m_TabStops #:init-value '()
	      #:getter get-tab-stops
	      #:setter set-tab-stops!)

  ;; The width in units
  (m_ThinSpaceWidth #:init-value #f
		    #:getter get-thin-space-width
		    #:setter set-thin-space-width!)

  ;; The SSU enum type for units
  (m_ThinSpaceUnits #:init-value 0
		    #:getter get-thin-space-units
		    #:setter set-thin-space-units!)
  
  (m_VertTabStops #:init-value '()
		  #:getter get-vert-tab-stops
		  #:setter set-vert-tab-stops!)

  )

'((0 "CHARACTER"            #f)
  (1 "MILLIMETRE"           (/ 1.0 25.4) 3.937e-2)
  (2 "COMPUTER DECIPOINT"   (/ 1.0 720.0) 1.389e-3)
  (3 "DECIDIDOT"            (/ (/ 10.0 266.0) 25.4) 1.480e-3)
  (4 "MIL"                  (/ 1.0 1000.0) 0.001000)
  (5 "BASIC MEASURING UNIT" (/ 1.0 1200.0) 8.333e-4)
  (6 "MICROMETER"           (/ 0.001 25.4) 3.937e-5)
  (7 "PIXEL"                #f)
  (8 "DECIPOINT"            (/ (/ 35.0 996.0) 25.4) 1.383e-3))

(define (make-ecma48-buffer)
  (let ((buf (make <Ecma48Buffer>)))
    buf))

(define (ecma48-buffer? buf)
  (is-a? buf <Ecma48Buffer>))

(define (console-bell Buf)
  (warn-if-false (ecma48-buffer? Buf))
  (log-debug "Bell")
  (let ((cb (get-alarm-callback Buf)))
    (when cb
      (cb))))


;; ACK - ACKNOWLEDGE
(define (acknowledge Buf)
  "Receipt of an ACK is an error by upstream. We ignore it."
  (log-debug "Received erroneous ACK")
  #f)

;; APC - APPLICATION PROGRAM COMMAND
(define (application-program-command Buf Msg)
  "Received a messaged.  It is forwarded to the message buffer."
  (let ((port (get-message-port Buf)))
    (when port
      (log-debug "Sending APC.")
      (display Msg port)
      (force-output port))))

;; ACS - ANNOUNCEMENT OF CODE STRUCTURE
;; ECMA-35 uses this to set up what type of shift
;; we're going to allow.

;; BEL - BELL
(define (bell Buf)
  "Received a #\bel character.  If an alert callback is defined,
it is called."
  (log-debug "Received BEL.")
  (when (get-alarm-callback Buf)
    (log-debug "Calling alarm callback func.")
    ((get-alarm-callback Buf))))

;; BPH - BREAK PERMITTED HERE
(define (break-permitted-here Buf)
  "Received an BPH character.  We ignore it."
  (log-debug "Received BPH.")
  #f)

;; BS - BACKSPACE
(define (backspace! Buf)
  "Moves the active data position one character position in
the direction opposite to that of the implicit movement."
  )

;; CAN - CANCEL
(define (cancel! Buf)
  (undo Buf))

;; CBT - CURSOR BACKWARD TABULATION
(define (cursor-backward-tabulation! Buf N)
  #f)

;; CCH - CANCEL CHARACTER
(define (cancel-character! Buf)
  (undo Buf))

;; CHA - CURSOR CHARACTER ABSOLUTE
(define (cursor-character-absolute! Buf Pp)
  "Move the cursor to 1-indexed position N in the presentation
component."
  ;; Convert presentaton position Pp to best data positon Pd
  ;; Set data position
  ;; Sync presentation and data positions.
  #f)

;; CMD - CODING METHOD DELIMITER is part of ECMA-35 grammar.
;; It indicates the end of using ECMA-35.  If I were to
;; fully implement this, it would basically return to
;; plain ASCII I guess, until a new ECMA-35 ACS is received.

;; CNL - CURSOR NEXT LINE
(define (cursor-next-line! Buf N)
  "Causes the active presentation position to be moved to the first
character position of the Nth following line in the presentation
component."
  ;; Convert presentaton line (+ L N) to the best data line.
  ;; Set data position
  ;; Sync presentation and data positions.
  #f)

;; CPR - ACTIVE POSITION REPORT
(define (active-position-report Buf U v)
  "Received an erroneous active position report from upstream."
  (log-debug "Received erroneous APR.")
  #f)

;; CR - CARRIAGE RETURN is handled by the cbuffer

;; CSI - is part of the grammar

;; CTC - CURSOR TABULATION CONTROL
;; clear some tab stops

;;
  
(define (scroll-right! Buf N)
  "Causes the presentation component to be moved by N character
positions so that the data appears to move to the right.  The active
position does not change."
  _)

;; set-reduced-character-separation (SRCS) establishes
;; reduces inter-character escapement for the subsequent text.

;; start-reversed-string (SRS) is ECMA-48's BiDi delimiters.

;; start-of-selected-area (SSA) is unimplemented

;; SU - SCROLL UP
(define (scroll-up! Buf N)
  "Causes the data in the presentation component to be moved by n line
positions if the line orientation is horizontal, or by n character
positions if the line orientation is vertical, such that the data
appear to move up.

The active presentation position is not affected."

  
;; SUB - SUBSTITUTE
(define (substitute Buf)
  "Called when a substitute character was received from the
input port.  Substitute characters are invalid and are
ignored."
  (log-debug "Received SUB. Ignored.")
  #f)

;; SVS - SELECT LINE SPACING

;; SYN - SYNCHRONOUS IDLE
(define (synchronous-idle Buf)
  "Sends a SYN character to the responsee port, usually is response
to the receipt of a SYN character from the input port."
  (let ((port (get-response-port Buf)))
    (when port
      (log-debug "Sending SYN.")
      (display #\syn port)
      (force-output port))))

;; TAC - TABULATION ALIGNED CENTRED

;; TALE - TABULATION ALIGNED LEADING EDGE

;; TATE - TABULATION ALIGNED TRAILING EDGE

;; TBC - TABULATION CLEAR

;; TCC - TABULATION CENTRED ON CHARACTER

;; TSR - TABULATION STOP REMOVE
(define (tabulation-stop-remove! Buf N)
  "Clears the tab stop at location N, if present."
  (set-tab-stops! Buf
		  (delete N (get-tab-stops Buf))))
  
;; TSS - THIN SPACE SPECIFICATION
(define (thin-space-specification Buf N)
  "Establishes the width of a thin space for subsequent text.
The units of the thin space are the units specified by the
SELECT SIZE UNIT (SSU) command."
  (set-thin-space-width! Buf N)
  (set-thin-space-units! Buf (get-size-unit Buf)))

;; VPA - LINE POSITION ABSOLUTE
(define (line-position-absolute! Buf L)
  "Move the active data position to the line position N in the data
component."
  ;; Ecma48 coords are 1-indexed.
  (let ((pd-cur (1+ (get-pd-cur Buf))))
    (pad-to-position! Buf (1- L) (1- pd-cur))
    (set-line-cur! Buf (1- L))
    (set-pd-cur! Buf (1- pd-cur))))

;; VPB - LINE POSITION BACKWARD
(define (line-position-backward! Buf N)
  "Move the active data position N line positions in the data
component in a direction opposite that of the line progression."
  (let* ((line-cur (get-line-cur Buf))
	 (pd-cur (get-pd-cur Buf)))
    (pad-to-position! Buf (- line-cur N) pd-cur)
    (set-line-cur! Buf (- line-cur N))
    (set-pd-cur! Buf pd-cur)))

;; VPR - LINE POSITION FORWARD
(define (line-position-forward! Buf N)
  "Move the active data position N line positions in the data
component in a direction parallel to the line progression."
  (let* ((line-cur (1+ (get-line-cur Buf)))
	 (pd-cur (1+ (get-pd-cur Buf))))
    ;; Ecma48 coords are 1-indexed
    (pad-to-position! Buf (1- (+ line-cur N)) (1- pd-cur))
    (set-line-cur! Buf (1- (+ line-cur N)))
    (set-pd-cur! Buf (1- pd-cur))))

;; VT - LINE TABULATION
(define (line-tabulation! Buf)
  "Causes the active presentation position to be moved in the
presentation component to the corresnpoding character positon on the
line at which the following line tabulation stop is set."
  ;; FIXME: this is a presentation operator, not a data operator.
  (let* ((line-cur (get-line-cur Buf))
	 (pd-cur (get-pd-cur Buf))
	 (vt (list-find-next-largest-entry
	      (get-vert-tab-stops Buf)
	      line-cur)))
    (when vt
      ;; Ecma48 coords are 1-indexed
      (pad-to-position! Buf (1- vt) (1- pd-cur))
      (set-line-cur! Buf (1- vt))
      (set-pd-cur! Buf (1- pd-cur)))))

;; VTS - LINE TABULATION SET
(define (line-tabulation-set! Buf)
  "Causes a line tabulation stop to be set at line L."
  (let ((L (get-line-cur Buf))
	(vt (get-vert-tab-stops Buf)))
    (unless (member L vt)
      (log-debug "New vertical tab stop added at line ~a" L)
      (set-vert-tab-stops! Buf (sort (append vt (list L)) <)))))

(define* (make-ecma48-receiver Mode Flags InputPort OutputPort
			       #:keys
			       (MessagePort #f)
			       (ResponseOutPort #f)
			       (DeviceCB1 #f)
			       (DeviceCB2 #f)
			       (AlarmCB #f)
			       (G1Table #f)
			       (G2Table #f)
			       (G3Table #f))

  
