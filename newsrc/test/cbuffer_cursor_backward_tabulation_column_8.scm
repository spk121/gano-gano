;; Copyright 2017 Michael L. Gran

;; This file is part of Gano.

;; Gano is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; Guile-Ncurses is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Lesser General Public License for more details.

;; You should have received a copy of the GNU Lesser General Public
;; License along with Guile-Ncurses.  If not, see
;; <http://www.gnu.org/licenses/>.

(use-modules (test automake-test-lib)
             (gano CBuffer))

;; If I try to backtab from the position of the first tab stop,
;; I should end up at the location of the zeroth tab stop.
(automake-test
 (let* ((CB (make-empty-cbuffer)))
   (let loop ((i 0))
     (when (< i 8)
       (write-character CB #\x 'data)
       (loop (1+ i))))
   (cursor-backward-tabulation CB 1)
   (= 0 (get-pd-cur CB))))
