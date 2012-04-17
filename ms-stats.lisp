(defconstant M_PI 3.141592653589793)

(defun list-median (l)
  (let ((r (sort l #'<))
        (c (floor (/ (length l) 2))))
    (float (nth c r) 0.0)))

(defun Norm_p (z)
  (let ((z (abs z)))
    (expt
     (1+ (* z
	    (+ 0.0498673470
	       (* z
		  (+ 0.0211410061
		     (* z
			(+ 0.0032776263
			   (* z
			      (+ 0.0000380036
				 (* z
				    (+ 0.0000488906
				       (* z 0.0000053830))))))))))))
     -16)))

(defun TtoZ (tv df)
  (let* ((a9 (- df 0.5))
         (b9 (* 48 a9 a9))
         (t9 (/ (* tv tv) df))
         z8 p7 b7)
    (if (>= t9 0.04)
        (setf z8 (* a9 (log (1+ t9))))
      (setf z8 (* a9 t9 (1+ (* t9 (- (/ (* t9 (- 1 (* t9 0.75))) 3) 0.5))))))
    (setf p7 (+ 85.5 (* z8 (+ 24 (* z8 (+ 3.3 (* 0.4 z8)))))))
    (setf b7 (+ (* 0.8 z8 z8) 100 b9))
    (* (sqrt z8) (1+ (/ (+ z8 3 (- (/ p7 b7))) b9)))
    ))

(defun TtoP (tv df)
  (let ((tsq (* tv tv))
        (tv (abs tv)))
    (cond ((= df 1)
           (- 1 (/ (* 2 (atan tv)) M_PI))
           )
          ((= df 2)
           (- 1 (/ tv (sqrt (+ tsq 2))))
           )
          ((= df 3)
           (- 1 (/ (* 2 (+ (atan (/ tv (sqrt 3))) (/ (* tv (sqrt 3)) (+ tsq 3)))) M_PI))
           )
          ((= df 4)
           (- 1 (/ (* tv (1+ (/ 2 (+ tsq 4)))) (sqrt (+ tsq 4))))
           )
          (t
           (Norm_p (TtoZ tv df))))))

(defun compute-models (lst1 lst2 out &optional (trials 30))
  (do ((x (car lst1) (car lst1))
       (y (car lst2) (car lst2)))
      ((null lst1) nil)
    (setf (app-property 'current-controller) (make-instance 'controller :model (make-instance 'model)))
    (let ((model (open-model (app-property 'current-controller) x)) data)
      (setf lst1 (cdr lst1) lst2 (cdr lst2))
      (cond
       (model
	(setf data nil)
	(with-open-file
	 (durations y :direction :input)
	 (do ((line (read-line durations nil nil) (read-line durations nil nil)))
	     ((null line) line)
	   (if (position #\Tab line)
	       (push (third (mapcar #'read-from-string (explode-tab line))) data)
	     (push line data))))
	(run-model
	 (app-property 'current-controller) trials
	 #'(lambda (method &rest args)
	     (case method
	       ('results
		(let ((times (mapcar #'trial-result-duration
				     (first args))))
		  (multiple-value-bind (tv df)
		      (t-test times data)
		    (let ((p (TtoP tv df))
			  (m1 (list-mean times))
			  (m2 (list-mean data)))
		      (format out "~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~%" x
			      #\tab (float m1 0.0)
			      #\tab (float (stdev times m1) 0.0)
			      #\tab (float m2 0.0)
			      #\tab (float (abs (* 100.0 (/ (- m1 m2) m2))) 0.0)
			      #\tab (float tv 0.0) #\tab df
			      #\tab (float p 0.0))))))
	       (t
		(if (eql 'error method)
		    (break)))))
	 :wait t :show nil))))))

(defun mann-whitney-u (list1 list2)
  (with-open-file (f "list1.txt" :direction :output :if-exists :supersede)
    (let (nl)
      (dolist (l list1)
        (format f (if nl "~%~A" "~A") (float l 0.0))
        (setf nl t))))
  (with-open-file (f "list2.txt" :direction :output :if-exists :supersede)
    (let (nl)
      (dolist (l list2)
        (format f (if nl "~%~A" "~A") (float l 0.0))
        (setf nl t))))
  (let ((stream (sys:open-pipe (list "/Library/Frameworks/Python.framework/Versions/2.7/bin/python2.7-32" "/Users/ewpatton/mannwhitneyu.py" "list1.txt" "list2.txt")))
        u p)
    (setf u (read stream))
    (setf p (read stream))
    (close stream)
    (values u p)))

(defun compute-models-mww (lst1 lst2 out &optional (trials 30))
  (do ((x (car lst1) (car lst1))
       (y (car lst2) (car lst2)))
      ((null lst1) nil)
    (setf (app-property 'current-controller) (make-instance 'controller :model (make-instance 'model)))
    (let ((model (open-model (app-property 'current-controller) x)) data)
      (setf lst1 (cdr lst1) lst2 (cdr lst2))
      (cond
       (model
        (setf data nil)
        (with-open-file
            (durations y :direction :input)
          (do ((line (read-line durations nil nil)
                     (read-line durations nil nil)))
              ((null line) line)
            (if (position #\Tab line)
                (push (third (mapcar #'read-from-string (explode-tab line))) data)
              (push line data))))
        (if (< 20 (length data))
        (run-model
         (app-property 'current-controller) trials
         #'(lambda (method &rest args)
             (case method
               ('results
                (let ((times (mapcar #'trial-result-duration
                                     (first args))))
                  (multiple-value-bind (u p)
                      (mann-whitney-u times data)
                    (let ((m1 (list-median times))
                          (m2 (list-median data)))
                      (format out "~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~%" x
                              #\tab (float m1 0.0)
                              #\tab (float (stdev times m1) 0.0)
                              #\tab (float m2 0.0)
                              #\tab (length times)
                              #\tab (length data)
                              #\tab u
                              #\tab p)))))
               (t
                (if (eql 'error method)
                    (break)))))
         :wait t :show nil)))))))

(defun compute-calib-results (path)
  (initialize)
  (let ((lst (directory (format nil "~A/*.san" path))))
    (setf lst (mapcar #'(lambda (x) (let* ((path (format nil "~A" x))
                                           (newpath (format nil "~A-durations.txt" (subseq path 0 (- (length path) 5)))))
                                      (list x newpath)))
                      lst))
    (let (a b)
      (dolist (x lst)
        (push (first x) a)
        (push (second x) b))
      (compute-models-mww a b *standard-output* 100))))

(defun compute-snt-results (path)
  (initialize)
  (let ((lst (directory (format nil "~A/*.san" path))))
    (setf lst (mapcar #'(lambda (x) (let* ((path (format nil "~A" x))
                                           (newpath (format nil "~A-durations.txt" (subseq path 0 (- (length path) 5)))))
                                      (list x newpath)))
                      lst))
    (let (a b)
      (dolist (x lst)
        (push (first x) a)
        (push (second x) b))
      (compute-models a b *standard-output*))))

(defun compute-dmap5-results (path)
  (initialize)
  (let ((lst (directory (format nil "~A/*.san" path))))
    (setf lst (mapcar #'(lambda (x) (let* ((path (format nil "~A" x))
                                           (newpath (format nil "~A-durations.txt" (subseq path 0 (- (length path) 5)))))
                                      (list x newpath)))
                      lst))
    (let (a b)
      (dolist (x lst)
        (push (first x) a)
        (push (second x) b))
      (compute-models a b *standard-output*))))
