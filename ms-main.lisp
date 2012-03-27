(defconstant *stack-warn-limit* (/ (megabytes 64) 4))
(defparameter *warned-about-stack* nil)
(defparameter *display-type*
  (get-activity-by-typename "Display Event"))
(defparameter *interactive* nil)
(defparameter *merge-trials* t)
(defparameter *fill-gaps* '("Cognitive Operator"))
(defparameter *answer* nil)
(defparameter *trial-limit* nil)
;(setf system:*stack-overflow-behaviour* :warn)

(defun bootstrap ()
  (let ((image-name (lw:lisp-image-name)))
    (if (not (or (contains image-name "LispWorks.app")
		 (contains image-name "LispWorks Personal.app")))
        (setf *app-path* 
	      (get-dir (lw:lisp-image-name))
	      *app-type*
	      #+win32 'windows #+cocoa 'mac)
      (setf *app-type* 'lispworks)))
  (setf *PROGRAM-DIRECTORY*
	(if (contains *app-path* "SANLab-CM.app")
	    (string-append *app-path* "Contents/")
	  *app-path*))
  (setf (app-property 'activity-types) nil)
  (setf (app-property 'model-width) 4000)
  (setf (app-property 'model-height) 1000)
  (setf (app-property 'grid-size) 10)
  (setf (app-property 'golden-ratio) (/ (+ 1 (sqrt 5)) 2))
  (setf (app-property 'initial-interface-height) 800)
  (setf (app-property 'initial-interface-width) 600)
  (setf (app-property 'min-pane-width) 300)
  (setf (app-property 'min-pane-height) 388)
  (setf (app-property 'min-obj-width) 110)
  (setf (app-property 'min-obj-height) 60)
  (load-properties
   (string-append *PROGRAM-DIRECTORY*
		  (if (equal *app-type* 'mac)
		      "../../properties.conf"
		    "properties.conf")))
  (read-activities
   (directory 
    (string-append *PROGRAM-DIRECTORY*
		   (if (equal *app-type* 'mac)
		       "../../Activities/*.sat"
		     "Activities/*.sat"))))
  (read-distributions 
   (directory 
    (string-append *PROGRAM-DIRECTORY*
		   (if (equal *app-type* 'mac)
		       "../../Distributions/*.spd"
		     "Distributions/*.spd"))))
  (read-interactive-routines 
   (directory 
    (string-append *PROGRAM-DIRECTORY*
		   (if (equal *app-type* 'mac)
		       "../../Interactive Routines/*.sir"
		     "Interactive Routines/*.sir")))))

(let ((last-display nil))
(defun get-last-display ()
  last-display)

(defmethod set-last-display ((res resource))
  (setf last-display res))
)

(defmacro generate-resource (&body args)
  (if (member :label args)
      `(make-instance 'resource ,@args
                      :duration (read-from-string
				 (first (parameters dep)))
                      :type (operator-type dep)
                      :id (uid dep))
    `(make-instance 'resource ,@args
                    :duration (read-from-string
			       (first (parameters dep)))
                    :type (operator-type dep)
                    :label (copy-seq (label dep))
                    :id (uid dep))))

(defmethod (setf resource-earliest-start-time) :before
  ((val t) (res resource))
  (let (*block*)
  (say "Changing earliest start time of UID ~A from ~A to ~A"
       (resource-id res)
       (resource-earliest-start-time res)
       val)))

(defmethod (setf resource-earliest-end-time) :before
  ((val t) (res resource))
  (let (*block*)
    (say "Changing earliest end time of UID ~A from ~A to ~A"
         (resource-id res)
         (resource-earliest-end-time res)
         val)))

(defmethod (setf resource-latest-start-time) :before
  ((val t) (res resource))
  (let (*block*)
    (say "Changing latest start time of UID ~A from ~A to ~A"
         (resource-id res)
         (resource-latest-start-time res)
         val)))

(defmethod (setf resource-latest-end-time) :before
  ((val t) (res resource))
  (let (*block*)
    (say "Changing latest end time of UID ~A from ~A to ~A"
         (resource-id res)
         (resource-latest-end-time res)
         val)))

(defmethod build-ir-instance ((routine interactive-routine)
			      &optional args)
  (let* ((result (make-hash-table))
         (lookup #'(lambda (x) (gethash (uid x) result))))
    (loop for dep in (task-list routine) do
          (let* ((label
		  (if (and args (gethash :label args))
		      (format nil "~A ~A"
			      (label dep)
			      (gethash :label args))
		    (label dep)))
                 (new-task
		  (generate-resource
		   :distribution (distribution dep)
		   :routine routine
		   :task dep
		   :label label
		   :parameters (mapcar #'read-from-string
				       (parameters dep))
		   )))
            (setf (gethash (uid dep) result) new-task)))
    (loop for dep in (task-list routine) do
          (let ((task (gethash (uid dep) result)))
            (setf (resource-predecessors task)
                  (mapcar lookup (edges-in dep))
                  (resource-dependents task)
                  (mapcar lookup (edges-out dep))
                  ))
          finally (return result)
          )))

(defmethod build-ir-instance2 ((routine interactive-routine)
                              (start hash-table)
                              (end hash-table)
                              (info hash-table)
                              (deps list)
                              &optional
			      (results (make-hash-table)))
  (let ((lookup #'(lambda (x) (gethash (uid x) results)))
        new-task label)
    (dolist (dep deps results)
      (cond ((gethash (uid dep) results) results)
            ((gethash (uid dep) start)
             (setf label
                   (if (and info (gethash :label info))
                       (format nil "~A ~A"
                               (label dep)
                               (gethash :label info))
                     (label dep)))
             (setf new-task
                   (generate-resource
                     :distribution (distribution dep)
                     :routine routine
                     :task dep
                     :label label
                     :parameters
		     (mapcar #'read-from-string
			     (parameters dep))))
             (setf (first (resource-parameters new-task))
                   (- (gethash (uid dep) end)
                      (gethash (uid dep) start)))
             (setf (resource-start-time new-task)
		   (gethash (uid dep) start))
             (setf (resource-end-time new-task)
		   (gethash (uid dep) end))
             (setf (resource-duration new-task)
                   (- (gethash (uid dep) end)
                      (gethash (uid dep) start)))
             (setf (gethash (uid dep) results) new-task)
             (build-ir-instance2 routine start end info
                                 (edges-out dep) results)
             (build-ir-instance2 routine start end info
                                 (edges-in dep) results)
             (setf (resource-dependents new-task)
                   (mapcar lookup (edges-out dep))
                   (resource-predecessors new-task)
                   (mapcar lookup (edges-in dep)))
             results)
            (t
             (setf label
                   (if (and info (gethash :label info))
                       (format nil "~A ~A"
                               (label dep)
                               (gethash :label info))
                     (label dep)))
             (setf new-task
                   (generate-resource
                     :distribution (distribution dep)
                     :routine routine
                     :task dep
                     :label label
                     :parameters
		     (mapcar #'read-from-string
			     (parameters dep))))
             (setf (gethash (uid dep) results) new-task)
             (let ((stl (mapcar #'(lambda (x) (if x (best-end-time x)))
                                (mapcar lookup (edges-in dep))))
                   (etl (mapcar #'(lambda (x) (if x (best-start-time x)))
                                (mapcar lookup (edges-out dep)))))
               (setf stl (remove-if #'null stl)
                     etl (remove-if #'null etl))
               (if (< 0 (length stl))
		   (setf (resource-earliest-start-time new-task)
			 (apply #'max stl)))
               (if (< 0 (length etl))
		   (setf (resource-latest-end-time new-task)
			 (apply #'min etl)))
               (if (valid-time? (resource-earliest-start-time new-task))
                   (setf (resource-earliest-end-time new-task)
			 (+ (resource-earliest-start-time new-task)
			    (first (resource-parameters new-task)))))
               (if (valid-time? (resource-latest-end-time new-task))
                   (setf (resource-latest-start-time new-task)
			 (- (resource-latest-end-time new-task)
			    (first (resource-parameters new-task))))))
             (build-ir-instance2 routine start end info
                                 (edges-out dep) results)
             (build-ir-instance2 routine start end info
                                 (edges-in dep) results)
             (setf (resource-dependents new-task)
                   (mapcar lookup (edges-out dep))
                   (resource-predecessors new-task)
                   (mapcar lookup (edges-in dep)))
             results)))))
  

(defmethod compute-earliest-start-time ((root resource)
					&optional
					(hint -inf))
  (declare (ignore hint))
  (let (*block*)
    (say "Computing earliest start time for UID ~A"
	 (resource-id root)))
  (let ((preds (resource-predecessors root)))
    (setf (resource-earliest-start-time root)
          (loop for pred in preds
                do (if (null (resource-earliest-start-time pred))
                       (compute-earliest-start-time pred))
                minimizing (+ (resource-earliest-start-time pred)
			      (resource-duration pred))))
    (if (resource-start-time root)
        (setf (resource-earliest-start-time root)
	      (resource-start-time root)))))

(defmethod compute-earliest-start-time ((items hash-table)
					&optional (hint -inf))
  (let (ends)
    (maphash #'(lambda (k v)
                 (declare (ignore k))
                 (if (= 0 (length (resource-predecessors v)))
                     (setf (resource-earliest-start-time v) hint))
                 (if (= 0 (length (resource-dependents v)))
                     (push v ends)))
             items)
    (loop for end in ends
          do (compute-earliest-start-time end)
          finally (return items))))

(defmethod compute-latest-start-time ((root resource)
				      &optional (hint +inf))
  (declare (ignore hint))
  (let (*block*)
    (say "Computing latest start time for UID ~A"
	 (resource-id root)))
  (let ((deps (resource-dependents root)))
    (setf (resource-latest-start-time root)
          (loop for dep in deps
                do (if (null (resource-latest-start-time dep))
                       (compute-latest-start-time dep))
                minimizing (- (resource-latest-start-time dep)
			      (resource-duration root))))
    (if (resource-start-time root)
        (setf (resource-latest-start-time root)
	      (resource-start-time root)))))

(defmethod compute-latest-start-time ((items hash-table)
				      &optional (hint +inf))
  (let (starts)
    (maphash #'(lambda (k v)
                 (declare (ignore k))
                 (if (= 0 (length (resource-predecessors v)))
                     (push v starts))
                 (if (= 0 (length (resource-dependents v)))
                     (setf (resource-latest-start-time v) hint)))
             items)
    (loop for start in starts
          do (compute-latest-start-time start)
          finally (return items))))

(defmethod compute-earliest-end-time ((root resource)
				      &optional (hint -inf))
  (let (*block*)
    (say "Computing earliest end time for UID ~A"
	 (resource-id root)))
  (let ((preds (resource-predecessors root)))
    (setf (resource-earliest-end-time root)
          (loop for pred in preds
                do (if (null (resource-earliest-end-time pred))
                       (compute-earliest-end-time pred))
                maximizing (+ (resource-earliest-end-time pred)
			      (resource-duration root))))
    (if (resource-end-time root)
        (setf (resource-earliest-end-time root)
	      (resource-end-time root)))))

(defmethod compute-earliest-end-time ((items hash-table)
				      &optional (hint -inf))
  (let (ends)
    (maphash #'(lambda (k v)
                 (declare (ignore k))
                 (if (= 0 (length (resource-predecessors v)))
                     (setf (resource-earliest-end-time v) hint))
                 (if (= 0 (length (resource-dependents v)))
                     (push v ends)))
             items)
    (loop for end in ends
          do (compute-earliest-end-time end)
          finally (return items))))

(defmethod compute-latest-end-time ((root resource)
				    &optional (hint +inf))
  (let (*block*)
    (say "Computing latest end time for UID ~A"
	 (resource-id root)))
  (let ((deps (resource-dependents root)))
    (setf (resource-latest-end-time root)
          (loop for dep in deps
                do (if (null (resource-latest-end-time dep))
                       (compute-latest-end-time dep))
                minimizing (- (resource-latest-end-time dep)
			      (resource-duration dep))))
    (if (resource-end-time root)
        (setf (resource-latest-end-time root)
	      (resource-end-time root)))))

(defmethod compute-latest-end-time ((items hash-table)
				    &optional (hint +inf))
  (let (starts)
    (maphash #'(lambda (k v)
                 (declare (ignore k))
                 (if (= 0 (length (resource-predecessors v)))
                     (push v starts))
                 (if (= 0 (length (resource-dependents v)))
                     (setf (resource-latest-end-time v) hint)))
             items)
    (loop for start in starts
          do (compute-latest-end-time start)
          finally (return items))
))

(defmethod compute-boundaries ((items hash-table))
  (compute-earliest-start-time items)
  (compute-latest-start-time items)
  (compute-earliest-end-time items)
  (compute-latest-end-time items))

(defmethod complete-ir-instance ((routine interactive-routine)
                                 (current resource)
                                 (arguments hash-table)
                                 &optional
				 (history (make-hash-table)))
  (block nil
    (if (gethash (resource-id current) history)
        (return)
      (setf (gethash (resource-id current) history) current))
    (let (*block*) (say "Processing uid ~A" (resource-id current)))
    (let* ((task (find (resource-id current)
		       (task-list routine)
		       :key #'uid))
           (deps (edges-out task))
           (preds (edges-in task)))
      ; Propogate information to predecessors
      (loop for dep in preds do
            (if (not (gethash (uid dep) history))
                (let ((new-task
		       (generate-resource
			:latest-end-time
			(if (resource-earliest-start-time current)
			    (resource-earliest-start-time current)
			  (- (resource-latest-end-time current)
			     (resource-duration current))))))
                  (setf (resource-dependents new-task) (list current))
                  (if (gethash :completion-callback arguments)
                      (funcall
		       (gethash :completion-callback arguments)
		       routine current new-task arguments))
                  (complete-ir-instance routine new-task
					arguments history))
              (let* ((task (gethash (uid dep) history))
                     (end-time 
                      (if (not (resource-latest-end-time current))
                          (resource-earliest-start-time current)
                        (- (resource-latest-end-time current)
                           (resource-duration current))))
                     (last-end-time (resource-latest-end-time task)))
                (push current (resource-dependents task))
                (if (resource-earliest-start-time task)
                    (setf end-time
			  (max
			   end-time
			   (+ (resource-earliest-start-time task)
			      (resource-duration task)))))
                (setf (resource-latest-end-time task)
                      (if last-end-time (max last-end-time end-time)
                        end-time)))))
      ; Propogate information to dependents
      (loop for dep in deps do
            (if (not (gethash (uid dep) history))
                (let ((new-task
		       (generate-resource
			:earliest-start-time
			(if (resource-latest-end-time current)
			    (resource-latest-end-time current)
			  (+ (resource-earliest-start-time current)
			     (resource-duration current))))))
                  (push new-task (resource-dependents current))
                  (if (gethash :completion-callback arguments)
                      (funcall
		       (gethash :completion-callback arguments)
		       routine current new-task arguments))
                  (complete-ir-instance routine new-task
					arguments history))
              (let* ((task (gethash (uid dep) history))
                     (start-time 
                      (if (not (resource-earliest-start-time current))
                          (resource-latest-end-time current)
                        (+ (resource-earliest-start-time current)
                           (resource-duration current))))
                     (first-start-time (resource-earliest-start-time task)))
                (push task (resource-dependents current))
                (if (resource-latest-end-time task)
                    (setf start-time
			  (min start-time
			       (- (resource-latest-end-time task)
				  (resource-duration task)))))
                (setf (resource-earliest-start-time task)
                      (if first-start-time
			  (max first-start-time start-time)
                        start-time)))))
      history)))

(defmethod generate-event (symbol start-time end-time &optional info)
  (declare (special *utilizes*))
  (let ((p (get-processor))
        (type (if (gethash :routine info) :routine :activity)))
    (cond ((and (in-trial? p) (eql type :routine))
           (let* ((routine-name (gethash :routine info))
                  (event-id (gethash :event-id info))
                  (utilizes (find routine-name
				  (if (boundp '*utilizes*)
				      *utilizes*
				    nil)
				  :test 'equal
				  :key 'car))
                  (iroutine (get-iroutine-by-name routine-name))
;                  (routine (build-ir-instance iroutine info)))
                  (routine
		   (build-ir-instance2
		    iroutine
		    start-time
		    end-time
		    info
		    (mapcar 
		     #'(lambda (x)
			 (find x (task-list iroutine)
			       :key #'uid))
		     event-id))))
             #|
             (dolist (id event-id)
               (let ((item (gethash id routine)))
                 (setf (resource-start-time item)
		       (gethash id start-time))
                 (setf (resource-end-time item)
		       (gethash id end-time))
                 (setf (resource-duration item)
		       (- (gethash id end-time)
			  (gethash id start-time)))
                 (setf (car (resource-parameters item))
		       (resource-duration item))))
             (compute-boundaries routine)
             |#
             (if utilizes
                 (let (acts queues)
                   (maphash #'(lambda (k v) (declare (ignore k))
                                (if (null (resource-predecessors v))
                                    (push v acts)))
                            routine)
                   (setf acts (sort acts #'< :key 'best-start-time))
                   (dolist (act acts)
                     (dolist (type (cdr utilizes))
                       (let ((op (get-activity-by-typename type)))
                         (maphash
			  #'(lambda (k v)
			      (if (is-supertype-of? op k)
				  (dolist (q v)
				    (push q queues))))
			  (processor-queues (get-processor))))
                       (dolist (queue queues)
                         (scan-and-split act queue :method :start))))))
             (schedule-iroutine routine p)))
          ((and (in-trial? p) (eql type :activity))
           (let* ((activity-name (gethash :activity info))
                  (distribution-name (gethash :distribution info))
                  (label (let ((f (gethash :label info)))
                           (if (functionp f) (funcall f info) f)))
                  (activity (get-activity-by-typename activity-name))
                  (resource
		   (make-instance 'resource
				  :earliest-start-time start-time
				  :latest-end-time end-time
				  :start-time start-time
				  :end-time end-time
				  :duration (- end-time start-time)
				  :parameters
				  (mapcar
				   #'read-from-string
				   (get-default-params activity))
				  :type activity
				  :label label
				  :distribution distribution-name))
                  types)
             (setf (first (resource-parameters resource))
		   (- end-time start-time))
             (if (null (gethash activity (processor-queues p)))
                 (error "Specified activity type not tracked by current processor"))
             (maphash
	      #'(lambda (k v)
		  (declare (ignore v))
		  (pushnew k types))
	      (processor-queues p))
             (schedule-resource
	      resource
	      (best-queue-for-resource
	       p
	       (most-specific-superclass (resource-type resource)
					 types)
	       resource)))))))

(defmethod merge-hash-tables (h1 h2)
  (maphash #'(lambda (k v) (setf (gethash k h1) v)) h2))

(defmethod raise-event ((event symbol) (start hash-table)
			(end hash-table) &optional args)
  (declare (special *event-mapping*))
  (if (not (boundp '*event-mapping*))
      (error "No *event-mapping* defined"))
  (mapc #'(lambda (x)
            (if (eql (first x) event)
                (let ((info (alist-to-hash-table (rest x))))
                  (merge-hash-tables info args)
                  (funcall #'generate-event event start end info))))
        *event-mapping*))

(defmethod raise-event ((event symbol) (start number) (end number)
			&optional args)
  (declare (special *event-mapping*))
  (if (not (boundp '*event-mapping*))
      (error "No *event-mapping* defined"))
  (mapc #'(lambda (x)
            (if (eql (first x) event)
                (let ((info (alist-to-hash-table (rest x))))
                  (merge-hash-tables info args)
                  (funcall #'generate-event event start end info))))
        *event-mapping*))

(defmethod size-of-graph ((res resource)
			  &optional (state (make-hash-table)))
  (if (not (resource-children-count res))
      (progn
        (setf (gethash res state) t)
        (dolist (i (resource-dependents res)) (size-of-graph i state))
        (setf (resource-children-count res) (hash-table-count state)))
    (resource-children-count res)))

(defmethod isomorphic-checker ((graph1 resource) (graph2 resource)
                               (map1 hash-table) (map2 hash-table)
                               &optional (ignore-types nil))
  (let* ((type-part (make-hash-table)))
    (block failed
      (if (/= (length (resource-dependents graph1))
              (length (resource-dependents graph2)))
          (return-from failed))
      (mapc #'(lambda (a b)
                (let ((typea (length (resource-dependents a)))
                      (typeb (length (resource-dependents b))))
                  (if (gethash typea type-part)
                      (push a (first (gethash typea type-part)))
                    (setf (gethash typea type-part)
			  (list (list a) nil)))
                  (if (gethash typeb type-part)
                      (push b (second (gethash typeb type-part)))
                    (setf (gethash typeb type-part)
			  (list nil (list b))))))
            (resource-dependents graph1) (resource-dependents graph2))
      (maphash
       #'(lambda (type entries)
	   (declare (ignore type))
	   (if (/= (length (first entries))
		   (length (second entries)))
	       (return-from failed))
	   (let ((child-part (make-hash-table)))
	     (mapc #'(lambda (a b)
		       (let ((lena (length (resource-dependents a)))
			     (lenb (length (resource-dependents b))))
			 (if (gethash lena child-part)
			     (push a
				   (first
				    (gethash 
				     lena
				     child-part)))
			   (setf (gethash lena child-part)
				 (list (list a) nil)))
			 (if (gethash lenb child-part)
			     (push b
				   (second
				    (gethash
				     lenb
				     child-part)))
			   (setf (gethash lenb child-part)
				 (list nil (list b))))))
		   (first entries) (second entries))
	     (maphash
	      #'(lambda (num entries)
		  (declare (ignore num))
		  (if (/= (length (first entries))
			  (length (second entries)))
		      (return-from failed))
		  (dolist (a (first entries))
		    (dolist (b (second entries))
		      (if (equal (gethash a map1)
				 (gethash b map2))
			  (cond ((null (gethash a map1))
				 (if (isomorphic-checker
				      a b map1 map2)
				     t)))))))
	      child-part)))
       type-part)
      (values map1 map2))))

(defmethod compute-depths ((res resource))
  (dolist (i (resource-dependents res))
    (cond ((< (resource-depth i) (1+ (resource-depth res)))
           (setf (resource-depth i) (1+ (resource-depth res)))
           (compute-depths i)))))

(defmethod flatten-graph ((res resource))
  (if (not (< (resource-depth res)
	      (resource-depth (first (resource-dependents res)))))
      (compute-depths res))
  (let (res (l (list res)))
    (do ((x (car l) (car l)))
        ((null l) (sort res #'< :key #'resource-depth))
      (setf l (cdr l))
      (cond ((not (member x res))
             (push x res)
             (dolist (child (resource-dependents x))
               (pushnew child l)))))))

(defmethod end-node ((graph resource))
  (if (resource-dependents graph)
      (end-node (first (resource-dependents graph)))
    graph))

(defmethod check-isomorphic ((graph1 resource) (graph2 resource)
			     (map1 hash-table) (map2 hash-table))
  ; Two nodes are isomorphic if for all dependents there is a one-to-one mapping of the dependents of one graph
  ; into the other and vise versa. The mappings are represented by map1 and map2, resp.
  (dolist (c1 (resource-dependents graph1) t)
    (let (found)
      (dolist (c2 (resource-dependents graph2))
        (if (and (equal (gethash c1 map1) c2)
                 (equal (gethash c2 map2) c1))
            (and (setf found t) (return))))
      (if (not found) (return)))))

(defun isomorphism-helper (items m1 m2) (declare (ignore type))
  (block failed
    (destructuring-bind (l1 l2) items
      (if (/= (length l1) (length l2)) (return-from failed))
      (dolist (a l1 t)
        (let (found)
          (dolist (b l2)
            (if (check-isomorphic a b m1 m2)
                (and (setf found t (gethash a m1) b (gethash b m2) a)
                     (return))))
          (if (not found) (return-from failed)))))))

(defmethod are-isomorphic-2? ((graph1 resource) (graph2 resource) &optional (ignore-types nil))
  (block failed
    (let ((g1 (flatten-graph graph1)) (g2 (flatten-graph graph2))
          (m1 (make-hash-table)) (m2 (make-hash-table)) a1 a2)
      ; Check that the graphs are the same cardinality
      (if (/= (length g1) (length g2)) (return-from failed))
      ; Check that the diameters of the graphs are the same
      (if (/= (resource-depth (first (last g1)))
	      (resource-depth (first (last g2))))
	  (return-from failed))

      ; Partition into levels
      (setf a1 (make-array (1+ (resource-depth (first (last g1))))))
      (setf a2 (make-array (1+ (resource-depth (first (last g2))))))
      (mapcar #'(lambda (x) (push x (elt a1 (resource-depth x)))) g1)
      (mapcar #'(lambda (x) (push x (elt a2 (resource-depth x)))) g2)
      
      ; Configure start state
      (mapcar #'(lambda (a b m)
                  (setf (gethash (first (elt a (1- (length a)))) m)
                        (first (elt b (1- (length b))))))
              (list a1 a2) (list a2 a1) (list m1 m2))
      
      (loop for i from (- (length a1) 2) downto 0 do
            (let ((l1 (elt a1 i)) (l2 (elt a2 i))
                  (type-part (make-hash-table)))
              (if (/= (length l1) (length l2)) (return-from failed))
              (mapc
	       #'(lambda (x y)
		   (if (gethash (resource-type x) type-part)
		       (push x (first (gethash (resource-type x)
					       type-part)))
		     (setf (gethash (resource-type x) type-part)
			   (list (list x) nil)))
		   (if (gethash (resource-type y) type-part)
		       (push y (second (gethash (resource-type y)
						type-part)))
		     (setf (gethash (resource-type y) type-part)
			   (list nil (list y)))))
	       l1 l2)
              (maphash
	       #'(lambda (k v)
		   (declare (ignore k))
		   (if (not (isomorphism-helper v m1 m2))
		       (return-from failed)))
                       type-part)))
      ; Done, return mapping
      (values m1 m2))))

; Two SANLab graphs are isomorphic in the following case:
; * The two nodes have the same type
; * The two nodes have the same extra data
; * The two nodes have the same number of children
; * Every child of the first node is isomorphic to at least 1 node of the other
(defmethod are-isomorphic? ((graph1 resource) (graph2 resource)
			    &optional (ignore-types nil)
			    (hash (make-hash-table)))
  (if (= (size-of-graph graph1) (size-of-graph graph2))
  (cond
   ((and (eq (gethash graph1 hash) graph2)
	 (eq (gethash graph2 hash) graph1))
    hash)
   ((or (gethash graph1 hash) (gethash graph2 hash))
    nil)
   (t
    (if (equal (resource-type graph1) (resource-type graph2))
	(if (member (resource-type graph1) ignore-types)
	    hash
	  (if (equal (resource-extra graph1)
		     (resource-extra graph2))
	      (cond
	       ((= (length (resource-dependents graph1))
		   (length (resource-dependents graph2)))
	      	; Inefficient O(n*m) loop, but n and m should be small (i.e. < 5)
		(setf (gethash graph1 hash) graph2
		      (gethash graph2 hash) graph1)
		(let* ((check
			#'(lambda (x)
			    #'(lambda (y)
				(loop for n in x do
				      (if (are-isomorphic?
					   y n ignore-types
					   hash)
					  (return n))))))
		       (g1-iso
			(mapcar
			 (funcall check
				  (resource-dependents graph2))
			 (resource-dependents graph1)))
		       (g2-iso
			(mapcar
			 (funcall check
				  (resource-dependents graph1))
			 (resource-dependents graph2))))
		  (if (and (not (member nil g1-iso))
			   (not (member nil g2-iso)))
		      hash
		    (progn
		      (remhash graph1 hash)
		      (remhash graph2 hash)
		      nil))))))))))))

(defmethod merge-trials ((self resource) (mapping hash-table))
  (if (numberp (resource-duration self))
      (setf (resource-duration self) (list (resource-duration self))))
  (if (numberp (first (resource-parameters self)))
      (setf (first (resource-parameters self))
	    (list (first (resource-parameters self)))))
  (let ((analog (gethash self mapping)))
    (push (resource-duration analog)
	  (resource-duration self))
    (push (resource-duration analog)
	  (first (resource-parameters self))))
  (remhash self mapping)
  (loop for child in (resource-dependents self) do
        (let ((analog (gethash child mapping)))
          (if analog (merge-trials child mapping)))))

(defmethod merge-trials ((self start-resource) (mapping hash-table))
  (if (numberp (resource-duration self))
      (setf (resource-duration self) (list (resource-duration self))))
  (if (numberp (first (resource-parameters self)))
      (setf (first (resource-parameters self))
	    (list (first (resource-parameters self)))))
  (let ((analog (gethash self mapping)))
    (setf (start-resource-trial-duration self)
          (append (start-resource-trial-duration analog)
                  (start-resource-trial-duration self)))
    (push (resource-duration analog)
	  (resource-duration self))
    (push (resource-duration analog)
	  (first (resource-parameters self))))
  (remhash self mapping)
  (loop for child in (resource-dependents self) do
        (let ((analog (gethash child mapping)))
          (if analog (merge-trials child mapping)))))

(defmethod attempt-merge-trials ((trials list) (cur-trial resource))
  (if (null trials)
      (list cur-trial)
    (cond (*merge-trials*
           (let (found)
             (loop for entry in trials do
		   (if (= (size-of-graph entry)
			  (size-of-graph cur-trial))
		       (let ((map (are-isomorphic-2? entry cur-trial)))
			 (cond
			  (map
			   (merge-trials entry map)
			   (setf found t) (return))))))
             (if (not found) (push cur-trial trials) 
                 trials)))
          (t
           (push cur-trial trials)))))

(defmethod fill-gap ((first resource) (next resource)
		     (type activity-type))
  (fill-gap (list first) next type))

(defmethod fill-gap ((queue list) (next resource)
		     (type activity-type))
  (let ((last (first (last queue)))
        (params (mapcar #'read-from-string (default-params type)))
        (dist "Multi-Unit Gamma CV")
        dur count act)
    (if (and (resource-latest-start-time next)
	     (= +inf (resource-latest-start-time next)))
        (setf (resource-latest-start-time next) nil))
    (if (and (resource-latest-end-time next)
	     (= +inf (resource-latest-end-time next)))
        (setf (resource-latest-end-time next) nil))
    (if (and (resource-earliest-start-time next)
	     (= -inf (resource-earliest-start-time next)))
        (setf (resource-earliest-start-time next) nil))
    (if (and (resource-earliest-end-time next)
	     (= -inf (resource-earliest-end-time next)))
        (setf (resource-earliest-end-time next) nil))
    (cond ((member next (resource-dependents last))
           (append queue (list next)))
          ((and (resource-end-time last) (resource-start-time next))
           (setf dur (- (resource-start-time next)
			(resource-end-time last)))
           (if (< dur 0) (setf dur 0))
           (setf count (ceiling (/ dur (first params))))
           (setf act
		 (make-instance
		  'resource
		  :start-time (resource-end-time last)
		  :end-time (resource-start-time next)
		  :duration dur
		  :distribution dist
		  :parameters
		  (list dur
			(if (second params)
			    (second params)
			  '(random 0.1 1.0 1))
			count)
		  :label "Unknown"
		  :type type
		  :predecessors (list last)
		  :dependents (list next)))
           (setf (resource-queue-number act)
                 (position
		  (first (gethash
			  type
			  (processor-queues
			   (get-processor))))
		  (flatten (as-list
			    (processor-queues
			     (get-processor))))))
           (push act (resource-dependents last))
           (push act (resource-predecessors next))
           (append queue (list act next)))
          ((and (resource-end-time last)
		(resource-latest-start-time next))
           (setf dur (- (resource-latest-start-time next)
			(resource-end-time last)))
           (if (< dur 0) (setf dur 0))
           (setf count (ceiling (/ dur (first params))))
           (setf act
		 (make-instance
		  'resource
		  :start-time (resource-end-time last)
		  :end-time (resource-latest-start-time next)
		  :duration dur
		  :distribution dist
		  :parameters
		  (list dur
			(if (second params)
			    (second params)
			  '(random 0.1 1.0 1))
			count)
		  :label "Unknown"
		  :type type
		  :predecessors (list last)
		  :dependents (list next)))
           (setf (resource-queue-number act)
                 (position (first
			    (gethash
			     type
			     (processor-queues
			      (get-processor))))
                           (flatten (as-list
				     (processor-queues
				      (get-processor))))))
           (push act (resource-dependents last))
           (push act (resource-predecessors next))
           (append queue (list act next)))
          ((and (resource-end-time last)
		(resource-earliest-start-time next))
           (setf dur (- (resource-earliest-start-time next)
			(resource-end-time last)))
           (if (< dur 0) (setf dur 0))
           (setf count (ceiling (/ dur (first params))))
           (setf act
		 (make-instance
		  'resource
		  :start-time (resource-end-time last)
		  :end-time (resource-earliest-start-time next)
		  :duration dur
		  :distribution dist
		  :parameters
		  (list dur
			(if (second params)
			    (second params)
			  '(random 0.1 1.0 1))
			count)
		  :label "Unknown"
		  :type type
		  :predecessors (list last)
		  :dependents (list next)))
           (setf (resource-queue-number act)
                 (position (first
			    (gethash
			     type
			     (processor-queues
			      (get-processor))))
                           (flatten (as-list
				     (processor-queues
				      (get-processor))))))
           (push act (resource-dependents last))
           (push act (resource-predecessors next))
           (append queue (list act next)))
          ((and (resource-latest-end-time last)
		(resource-start-time next))
           (setf dur (- (resource-start-time next)
			(resource-latest-end-time last)))
           (if (< dur 0) (setf dur 0))
           (setf count (ceiling (/ dur (first params))))
           (setf act
		 (make-instance
		  'resource
		  :start-time (resource-latest-end-time last)
		  :end-time (resource-start-time next)
		  :duration dur
		  :distribution dist
		  :parameters
		  (list dur
			(if (second params)
			    (second params)
			  '(random 0.1 1.0 1))
			count)
		  :label "Unknown"
		  :type type
		  :predecessors (list last)
		  :dependents (list next)))
           (setf (resource-queue-number act)
                 (position (first
			    (gethash
			     type
			     (processor-queues
			      (get-processor))))
                           (flatten (as-list
				     (processor-queues
				      (get-processor))))))
           (push act (resource-dependents last))
           (push act (resource-predecessors next))
           (append queue (list act next)))
          ((and (resource-latest-end-time last)
		(resource-latest-start-time next))
           (setf dur (- (resource-latest-start-time next)
			(resource-latest-end-time last)))
           (if (< dur 0) (setf dur 0))
           (setf count (ceiling (/ dur (first params))))
           (setf act
		 (make-instance
		  'resource
		  :start-time (resource-latest-end-time last)
		  :end-time (resource-latest-start-time next)
		  :duration dur
		  :distribution dist
		  :parameters
		  (list dur
			(if (second params)
			    (second params)
			  '(random 0.1 1.0 1))
			count)
		  :label "Unknown"
		  :type type
		  :predecessors (list last)
		  :dependents (list next)))
           (setf (resource-queue-number act)
                 (position (first
			    (gethash
			     type
			     (processor-queues
			      (get-processor))))
                           (flatten (as-list
				     (processor-queues
				      (get-processor))))))
           (push act (resource-dependents last))
           (push act (resource-predecessors next))
           (append queue (list act next)))
          ((and (resource-latest-end-time last)
		(resource-earliest-start-time next))
           (setf dur (- (resource-earliest-start-time next)
			(resource-latest-end-time last)))
           (if (< dur 0) (setf dur 0))
           (setf count (ceiling (/ dur (first params))))
           (setf act
		 (make-instance
		  'resource
		  :start-time (resource-latest-end-time last)
		  :end-time (resource-earliest-start-time next)
		  :duration dur
		  :distribution dist
		  :parameters
		  (list dur
			(if (second params)
			    (second params)
			  '(random 0.1 1.0 1))
			count)
		  :label "Unknown"
		  :type type
		  :predecessors (list last)
		  :dependents (list next)))
           (setf (resource-queue-number act)
                 (position (first
			    (gethash
			     type
			     (processor-queues
			      (get-processor))))
                           (flatten (as-list
				     (processor-queues
				      (get-processor))))))
           (push act (resource-dependents last))
           (push act (resource-predecessors next))
           (append queue (list act next)))
          (t
           (pushnew last (resource-predecessors next))
           (pushnew next (resource-dependents last))
           (append queue (list next)))
          )))

(defmethod fill-gaps ((proc processor) (type activity-type))
  (let ((constraint (resource-constraint-for-activity proc type)))
    (cond
     ((and constraint
	   (eq (resource-constraint-method constraint)
	       'serial))
      (if (< 1 (length (resource-queue-tree
			(first (resource-constraint-queues
				constraint)))))
	  (setf (resource-queue-tree
		 (first (resource-constraint-queues
			 constraint)))
		(reduce #'(lambda (x y)
			    (fill-gap x y type)) 
			(resource-queue-tree
			 (first (resource-constraint-queues
				 constraint)))))))
     (constraint
      (let (*block*) (say "*** Warning: tried to fill gaps for parallel constraints, not sure how to proceed at the moment.")))
     (t
      (let (*block*) (say "*** Warning: unable to find type ~A in list of constraints" type))))))

(defmethod fill-gaps ((proc processor) (type string))
  (fill-gaps proc (get-activity-by-typename type)))

(defmethod compute-params ((res resource))
  (let ((dist (get-distribution-by-typename
	       (resource-distribution res)))
        ans std mean)
    (do ((var (param-symbols dist) (cdr var))
         (val (resource-parameters res) (cdr val)))
        ((null var) (reverse ans))
      (push
       (cond ((and (equal (car var) 'cv)
                   std)
              (if (= mean 0.0)
                  (format nil "0.0")
                (format nil "~A"
			(* 0.001D0 (fround
				    (float (/ std mean))
				    0.001D0)))))
             ((and (equal (car var) 'std) std)
              (format nil "~A" std))
             ((and (listp (car val))
                   (numberp (first (car val))))
              (setf mean
		    (round (float (mean (car val)))))
              (setf std
		    (round (float (standard-deviation (car val)))))
              (format nil "~A" mean))
             (t
             (format nil "~A" (car val))))
       ans))))

(defmethod resource-graph-to-sanlab-model ((res resource)
					   &optional model)
  (if (null (app-property 'current-controller))
      (setf (app-property 'current-contorller)
	    (make-instance 'controller)))
  (if (null model)
      (setf (model (app-property 'current-controller))
	    (setf model (make-instance 'model))))
  (if (null (resource-node res))
      (progn
        (if (and (equal (resource-distribution res)
                        "Constant")
                 (listp (resource-duration res))
                 (< 1 (length (resource-duration res))))
            (setf (resource-distribution res) "Gamma CV"))
        (setf (resource-node res)
              (create-activity-in-model
               model (resource-type res)
               :x (* (resource-depth res) 200)
               :y (* (resource-queue-number res) 150)
               :ir-type (resource-iroutine res)
               :ir-task (resource-iroutine-task res)
               :ir-append ""
               :label (resource-label res)
               :distribution (resource-distribution res)
               :params (compute-params res)))))
  (setf (edges-out (resource-node res))
        (mapcar #'(lambda (x) 
                    (if (not (resource-node x))
                        (resource-graph-to-sanlab-model x model))
                    (resource-node x))
                (resource-dependents res)))
  (setf (edges-in (resource-node res))
        (mapcar #'(lambda (x)
                    (if (not (resource-node x))
                        (resource-graph-to-sanlab-model x model))
                    (resource-node x))
                (resource-predecessors res)))
  (if (edges-in (resource-node res))
      (setf (stored-x (resource-node res))
            (+ 200 (max-func
		    (mapcar #'stored-x
			    (edges-in (resource-node res)))))))
  (cond ((= (resource-depth res) 0)
         (setf (width model)
	       (+ 200 (max-func
		       (cons (- (width model) 200)
			     (mapcar #'stored-x
				     (activities model))))))
         (setf (height model)
	       (+ 150 (max-func
		       (cons (- (height model) 150)
			     (mapcar #'stored-y
				     (activities model))))))
         (Setf (title model) "Model generated from human data")
         ))
  model
)

(defprocessor human-machine
  (defconstraint "System"
    :constraint-type "System Resource"
    :count 1)
  (defconstraint "Perception"
    :constraint-type "Perceptual Operator (Visual)"
    :count 1)
  (defconstraint "Perception"
    :constraint-type "Perceptual Operator (Auditory)"
    :count 1)
  (defconstraint "Cognition"
    :constraint-type "Cognitive Operator"
    :count 1)
  (defconstraint "Cognition"
    :constraint-type "Task-oriented Memory"
    :count 1)
  (defconstraint "Cognition"
    :constraint-type "Declarative Memory"
    :count 1)
  (defconstraint "Motor"
    :constraint-type "Eye Movement Operator"
    :count 1)
  (defconstraint "Motor"
    :constraint-type "Left Hand Operator"
    :count 1)
  (defconstraint "Motor"
    :constraint-type "Right Hand Operator"
    :count 1))

(defmethod configure-default-processor ()
(defprocessor human-machine
  (defconstraint "System"
    :constraint-type "System Resource"
    :count 1)
  (defconstraint "Perception"
    :constraint-type "Perceptual Operator (Visual)"
    :count 1)
  (defconstraint "Perception"
    :constraint-type "Perceptual Operator (Auditory)"
    :count 1)
  (defconstraint "Cognition"
    :constraint-type "Cognitive Operator"
    :count 1)
  (defconstraint "Cognition"
    :constraint-type "Task-oriented Memory"
    :count 1)
  (defconstraint "Cognition"
    :constraint-type "Declarative Memory"
    :count 1)
  (defconstraint "Motor"
    :constraint-type "Eye Movement Operator"
    :count 1)
  (defconstraint "Motor"
    :constraint-type "Left Hand Operator"
    :count 1)
  (defconstraint "Motor"
    :constraint-type "Right Hand Operator"
    :count 1))
)

(defmethod serialize-queue ((queue resource-queue))
  (if (and (resource-queue-tree queue)
           (<= 2 (length (resource-queue-tree queue))))
      (reduce #'(lambda (x y)
                  (if (and
		       ; prevents cycles
		       (not (path-between-nodes?
			     y x #'resource-dependents))
		       ; prevents redundancy
		       (not (path-between-nodes?
			     x y #'resource-dependents)))
                      (progn
                        (pushnew x (resource-predecessors y))
                        (pushnew y (resource-dependents x))))
                  y)
              (resource-queue-tree queue))))

(defmethod path-between-nodes? ((start resource) (end resource)
				(edges function) &optional
				(ht (make-hash-table)))
  (cond ((gethash start ht)
         nil)
        ((member end (funcall edges start))
         t)
        (t
         (setf (gethash start ht) start)
         (dolist (x (funcall edges start))
           (if (path-between-nodes? x end edges ht)
	       (return t))))))

(defmethod delete-forward ((item resource))
  (dolist (child (resource-dependents item))
    (dolist (queue (gethash (resource-type child)
			    (processor-queues (get-processor))))
      (if (member child (resource-queue-tree queue))
          (setf (resource-queue-tree queue)
		(remove child (resource-queue-tree queue)))))
    (setf (resource-predecessors child)
	  (remove item (resource-predecessors child)))
    (delete-forward child))
  (setf (resource-dependents item) nil))

(defmethod delete-backward ((item resource) (end number))
  (dolist (parent (resource-predecessors item))
    (setf (resource-dependents parent)
	  (remove item (resource-dependents parent)))
    (if (and (>= (best-start-time parent) end)
	     (< 0 (resource-duration item)))
        (progn
          (dolist (queue (gethash (resource-type parent)
				  (processor-queues (get-processor))))
            (if (member parent (resource-queue-tree queue))
                (setf (resource-queue-tree queue)
		      (remove parent (resource-queue-tree queue)))))
          (delete-forward parent)
          (delete-backward parent end))))
  (setf (resource-predecessors item) nil))

(defmethod run-protocol-analysis ((p parser) &key
				  (merge-trials nil)
				  (distribution nil)
                                  (trials (make-hash-table)))
  (declare (special *event-mapping*))
  (setf sys:*stack-overflow-behaviour* nil)
  (initialize-parser p)
  (say "Initialized parser successfully")

  ; Make sure *event-mapping* is defined
  (if (not (boundp '*event-mapping*)) (setf *event-mapping* nil))

  (let ((done t) (count 0) cur-trial)
    (do ()
        ((not done) trials)
      (multiple-value-bind (result args) (parse-item p)
        (mp:process-wait-for-event :no-hang-p t)
        (if (and (> (current-stack-length) *stack-warn-limit*)
		 (not *warned-about-stack*))
            (progn
              (format t " ** WARNING ** Stack very large. This could indicate a cyclic dependency structure. Enter :continue to continue, :abort to quit.~%")
              (setf *warned-about-stack* t)
              (let ((sym (read)))
                (if (eq sym :abort) (return trials)))))
        (if distribution (setf (gethash :distribution args) distribution))
        (cond
	 ((eql result 'continue)
	  (let (*block*) (say "Continuing...")))
	 ((eql result 'start-trial)
	  (print-if *super-debug*
		    "Starting new trial at ~A~%"
		    (gethash :start args))
	  (let ((*interactive* t) *block*)
	    (say "Starting new trial at ~A"
		 (gethash :start args)))
	  (reset-processor (get-processor))
	  (setf (trial (get-processor)) (gethash :start args)))
	 ((eql result 'end-trial)
	  (let ((*interactive* t) *block*)
	    (say "Stopping trial at ~A"
		 (gethash :end args)))
	  (if (not (in-trial? (get-processor)))
	      (error "Stopping a trial that hasn't be started!"))
	  (maphash
	   #'(lambda (k v)
	       (declare (ignore k))
	       (mapcar
		#'(lambda (q)
		    (let ((item (first (last (resource-queue-tree q)))))
		      (cond 
		       ((null item) nil)
		       ((and (>= (best-start-time item)
				 (gethash :end args))
			     (< 0 (resource-duration item)))
			(delete-forward item)
			(delete-backward item (gethash :end args))
			(dolist (queue
				 (gethash (resource-type item)
					  (processor-queues
					   (get-processor))))
			  (if (member item
				      (resource-queue-tree
				       queue))
			      (setf (resource-queue-tree queue)
				    (remove
				     item
				     (resource-queue-tree
				      queue))))))
			    ; Truncate activities that start in this trial but end
			    ; outside the trial
		       ((and (valid-time? (resource-end-time item))
			     (> (resource-end-time item)
				(gethash :end args)))
			(setf
			 (resource-end-time item)
			 (gethash :end args))
			(setf
			 (resource-duration item)
			 (- (resource-end-time item)
			    (resource-start-time item)))
			(setf (first (resource-parameters item))
			      (resource-duration item)))
		       ((and (valid-time? (resource-latest-end-time item))
			     (> (resource-latest-end-time item)
				(gethash :end args)))
			(setf
			 (resource-latest-end-time item)
			 (gethash :end args))
			(setf
			 (resource-duration item)
			 (- (resource-latest-end-time item)
			    (resource-latest-start-time item)))
			(setf
			 (first (resource-parameters item))
			 (resource-duration item)))
		       ((and (valid-time?
			      (resource-earliest-end-time item))
			     (> (resource-earliest-end-time item)
				(gethash :end args)))
			(setf
			 (resource-earliest-end-time item)
			 (gethash :end args))
			(setf
			 (resource-duration item)
			 (- (resource-earliest-end-time item)
			    (resource-earliest-start-time item)))
			(setf
			 (first (resource-parameters item))
			 (resource-duration item))))))
		v))
	   (processor-queues (get-processor)))
	   ;               (loop for type in *fill-gaps* do
	   ;                     (fill-gaps (get-processor) type))
	  (setf cur-trial
		(make-instance
		 'start-resource
		 :duration 0
		 :start-time (in-trial? (get-processor))
		 :end-time (in-trial? (get-processor))
		 :type (get-activity-by-typename "Cognitive Operator")
		 :label "Start Trial"
		 :distribution "Constant"
		 :parameters '(0)
		 :trial-duration
		 (list (list 
			(parser-subject p)
			(parser-trial p)
			(- (gethash :end args)
			   (in-trial? (get-processor)))))))
	  
	  (let ((end-trial
		 (make-instance
		  'resource
		  :duration 0
		  :type (get-activity-by-typename "Cognitive Operator")
		  :label "End Trial"
		  :distribution "Constant"
		  :parameters '(0))))
	    (setf (resource-queue-number end-trial)
		  (position (first
			     (gethash
			      (get-activity-by-typename
			       "Cognitive Operator")
			      (processor-queues
			       (get-processor))))
			    (flatten (as-list
				      (processor-queues
				       (get-processor))))))
	    (loop for queue-list in
		  (as-list (processor-queues (get-processor)))
		  do
		  (loop for queue in queue-list do 
			(let ((start
			       (first (resource-queue-tree
				       queue)))
			      (end
			       (first
				(last (resource-queue-tree
				       queue)))))
			  (if (or (not start) (not end)) (return))
			  (cond
			   ((not (member (typename (resource-type start))
					 *fill-gaps*
					 :test #'equal))
			    (push start
				  (resource-dependents cur-trial))
			    (push cur-trial
				  (resource-predecessors start))))
			  (push end
				(resource-predecessors end-trial))
			  (push end-trial
				(resource-dependents end)))))
	    (loop for constraint in
		  (flatten (as-list (processor-constraints
				     (get-processor))))
		  do
		  (if (eq (resource-constraint-method constraint)
			  'serial)
		      (mapc #'serialize-queue
			    (resource-constraint-queues constraint))))
	    (let ((queue (first
			  (gethash
			   (get-activity-by-typename
			    "Cognitive Operator")
			   (processor-queues
			    (get-processor))))))
	      (setf (resource-queue-number cur-trial)
		    (position queue
			      (flatten (as-list
					(processor-queues
					 (get-processor))))))
	      (setf (resource-queue-tree queue)
		    (cons cur-trial (resource-queue-tree queue))))
	    (loop for type in *fill-gaps* do
		  (fill-gaps (get-processor) type))
	    
	    (cond ((resource-dependents cur-trial)
		   (compute-depths cur-trial)
		   (if (gethash 'valid-trial args)
		       (if merge-trials
			   (setf (gethash
				  (gethash 'condition args)
				  trials)
				 (attempt-merge-trials
				  (gethash
				   (gethash 'condition args)
				   trials) cur-trial))
			 (push cur-trial
			       (gethash
				(gethash 'condition args)
				trials))))
		   (cond (*trial-limit*
			  (setf count (1+ count))
			  (if (= count *trial-limit*)
			      (return trials))))))
	    (setf (trial (get-processor)) nil)
	    (reset-processor (get-processor))))
	 ((member result *event-mapping* :key #'car)
	  (if (in-trial? (get-processor))
	      (let ((start (gethash :start args))
		    (end (gethash :end args)))
		(raise-event result start end args)
		(say "Processing event ~A" result))))
	 (result
	  (say "Unknown event ~A from parser" result))
	 (t
	  (setf done nil)
	  (say "Processing complete")))))
    (setf *answer* trials)))

(defun test-compute-boundaries ()
  (let* ((iroutine (get-iroutine-by-name "Slow Move-Click"))
         (items (build-ir-instance iroutine))
         (res (gethash 3 items)))
    (setf (resource-start-time res) 100.0)
    (setf (resource-end-time res) 645.0)
    (setf res (gethash 7 items))
    (setf (resource-start-time res) 200.0)
    (setf (resource-end-time res) 230.0)
    (setf res (gethash 9 items))
    (setf (resource-start-time res) 230.0)
    (setf (resource-end-time res) 330.0)
    (setf res (gethash 13 items))
    (setf (resource-start-time res) 845.0)
    (setf (Resource-end-time res) 945.0)
    (compute-boundaries items)
    items))

(defmethod run-on-alternate-thread (func)
  (mp:process-run-function
   "Processing Thread" '(:priority -100000)
   #'(lambda (in out err)
       (setf *standard-input* in)
       (setf *standard-output* out)
       (setf *error-output* err)
       (funcall func))
   *standard-input*
   *standard-output*
   *error-output*))

(defun check-aoi-circle (mx my args)
  (destructuring-bind (rx ry rr) args
    (let ((dx (- mx rx))
          (dy (- my ry)))
      (<= (+ (* dx dx) (* dy dy)) (* rr rr)))))

(defun check-aoi-rectangle (mx my args)
  (destructuring-bind (rx ry rw rh) args
    (let ((rx2 (+ rx rw))
          (ry2 (+ ry rh)))
      (and (<= rx mx) (< mx rx2)
           (<= ry my) (< my ry2)))))

(defun check-aoi (x y)
  (declare (special *areas-of-interest*))
  (if (not (boundp '*areas-of-interest*))
      (setf *areas-of-interest* nil))
  (dolist (aoi *areas-of-interest*)
    (case (cadr aoi)
      (:rectangle
       (if (check-aoi-rectangle x y (cddr aoi))
           (return (car aoi))))
      (:circle
       (if (check-aoi-circle x y (cddr aoi))
           (return (car aoi)))))))
