(in-package #:ecs-tutorial)

(define-constant +window-width+ 800)
(define-constant +window-height+ 600)

(define-constant +repl-update-interval+ 0.3d0)

(defvar *resources-path*
  (asdf:system-relative-pathname :ecs-tutorial #P"Resources/"))

(deploy:define-hook (:boot set-resources-path) ()
  (setf *resources-path*
        (merge-pathnames #P"Resources/"
                         (uiop:pathname-parent-directory-pathname
                          (deploy:runtime-directory)))))

(define-constant +font-path+ "inconsolata.ttf" :test #'string=)
(define-constant +font-size+ 24)

(define-constant +config-path+ "../config.cfg" :test #'string=)

;; Asteroid assets

(define-constant asteroid-images
    '("../Resources/a10000.png" "../Resources/a10001.png"
      "../Resources/a10002.png" "../Resources/a10003.png"
      "../Resources/a10004.png" "../Resources/a10005.png"
      "../Resources/a10006.png" "../Resources/a10007.png"
      "../Resources/a10008.png" "../Resources/a10009.png"
      "../Resources/a10010.png" "../Resources/a10011.png"
      "../Resources/a10012.png" "../Resources/a10013.png"
      "../Resources/a10014.png" "../Resources/a10015.png"
      "../Resources/b10000.png" "../Resources/b10001.png"
      "../Resources/b10002.png" "../Resources/b10003.png"
      "../Resources/b10004.png" "../Resources/b10005.png"
      "../Resources/b10006.png" "../Resources/b10007.png"
      "../Resources/b10008.png" "../Resources/b10009.png"
      "../Resources/b10010.png" "../Resources/b10011.png"
      "../Resources/b10012.png" "../Resources/b10013.png"
      "../Resources/b10014.png" "../Resources/b10015.png")
  :test #'equalp)

;; Component definitions

(ecs:define-component position
  "Determines the location of the object, in pixels."
  (x 0.0 :type single-float :documentation "X coordinate")
  (y 0.0 :type single-float :documentation "Y coordinate"))

(ecs:define-component speed
  "Determines the speed of the object, in pixels/second."
  (x 0.0 :type single-float :documentation "X coordinate")
  (y 0.0 :type single-float :documentation "Y coordinate"))

(ecs:define-component image
  "Stores ALLEGRO_BITMAP structure pointer, size and scaling information"
  (bitmap (cffi:null-pointer) :type cffi:foreign-pointer)
  (width 0.0 :type single-float)
  (height 0.0 :type single-float)
  (scale 1.0 :type single-float))

;; System definitions

(ecs:define-system draw-images
  (:components-ro (position image)
   :initially (al:hold-bitmap-drawing t)
   :finally (al:hold-bitmap-drawing nil))
  (let ((scaled-width (* image-scale image-width))
        (scaled-height (* image-scale image-height)))
    (al:draw-scaled-bitmap image-bitmap 0 0
                           image-width image-height
                           (- position-x (* 0.5 scaled-width))
                           (- position-y (* 0.5 scaled-height))
                           scaled-width scaled-height 0)))

(ecs:define-system move
  (:components-ro (speed)
   :components-rw (position)
   :arguments ((:dt single-float)))
  (incf position-x (* dt speed-x))
  (incf position-y (* dt speed-y)))



;; Initialization

(defun init ()
  (ecs:make-storage)
  (let ((asteroid-bitmaps
          (map 'list
               #'(lambda (filename)
                   (al:ensure-loaded
                     #'al:load-bitmap filename))
               asteroid-images)))
    (dotimes (_ 1000)
      (ecs:make-object `((:position
                          :x ,(float (random +window-width+))
                          :y ,(float (random +window-height+)))
                         (:image
                          :bitmap ,(alexandria:random-elt
                                     asteroid-bitmaps)
                          :width 64.0 :height 64.0)))))
)

(declaim (type fixnum *fps*))
(defvar *fps* 0)


;;; Update Loop

(defun update (dt)
  (unless (zerop dt)
    (setf *fps* (round 1 dt)))
  (ecs:run-systems))

(defvar *font*)

(defun render ()

  (al:draw-text *font* (al:map-rgba 255 255 255 0) 0 0 0
                (format nil "~d FPS" *fps*))

  ;; TODO : put your drawing code here
  )

(cffi:defcallback %main :int ((argc :int) (argv :pointer))
  (declare (ignore argc argv))
  (handler-bind
      ((error #'(lambda (e) (unless *debugger-hook*
                         (al:show-native-message-box
                          (cffi:null-pointer) "Hey guys"
                          "We got a big error here :("
                          (with-output-to-string (s)
                            (uiop:print-condition-backtrace e :stream s))
                          (cffi:null-pointer) :error)))))
    (uiop:chdir (setf *default-pathname-defaults* *resources-path*))
    (al:set-app-name "ecs-tutorial")
    (unless (al:init)
      (error "Initializing liballegro failed"))
    (let ((config (al:load-config-file +config-path+)))
      (unless (cffi:null-pointer-p config)
        (al:merge-config-into (al:get-system-config) config)))
    (unless (al:init-primitives-addon)
      (error "Initializing primitives addon failed"))
    (unless (al:init-image-addon)
      (error "Initializing image addon failed"))
    (unless (al:init-font-addon)
      (error "Initializing liballegro font addon failed"))
    (unless (al:init-ttf-addon)
      (error "Initializing liballegro TTF addon failed"))
    (unless (al:install-audio)
      (error "Intializing audio addon failed"))
    (unless (al:init-acodec-addon)
      (error "Initializing audio codec addon failed"))
    (unless (al:restore-default-mixer)
      (error "Initializing default audio mixer failed"))
    (al:set-new-display-flags '(:opengl))
    (al:set-new-display-option :alpha-size 8 :require)
    (let ((display (al:create-display +window-width+ +window-height+))
          (event-queue (al:create-event-queue)))
      (when (cffi:null-pointer-p display)
        (error "Initializing display failed"))
      (al:inhibit-screensaver t)
      (al:set-window-title display "ECS Tutorial for Lisp Gamedev")
      (al:register-event-source event-queue
                                (al:get-display-event-source display))
      (al:install-keyboard)
      (al:register-event-source event-queue
                                (al:get-keyboard-event-source))
      (al:install-mouse)
      (al:register-event-source event-queue
                                (al:get-mouse-event-source))
      (unwind-protect
           (cffi:with-foreign-object (event '(:union al:event))
             (init)
             (livesupport:setup-lisp-repl)
             (loop
               :named main-game-loop
               :with *font* := (al:ensure-loaded #'al:load-ttf-font
                                                 +font-path+
                                                 (- +font-size+) 0)
               :with ticks :of-type double-float := (al:get-time)
               :with last-repl-update :of-type double-float := ticks
               :with dt :of-type double-float := 0d0
               :while (loop
                        :named event-loop
                        :while (al:get-next-event event-queue event)
                        :for type := (cffi:foreign-slot-value
                                      event '(:union al:event) 'al::type)
                        :always (not (eq type :display-close)))
               :do (let ((new-ticks (al:get-time)))
                     (setf dt (- new-ticks ticks)
                           ticks new-ticks))
                   (when (> (- ticks last-repl-update)
                            +repl-update-interval+)
                     (livesupport:update-repl-link)
                     (setf last-repl-update ticks))
                   (al:clear-to-color (al:map-rgb 0 0 0))
                   (livesupport:continuable
                     (update dt)
                     (render))
                   (al:flip-display)
               :finally (al:destroy-font *font*)))
        (al:inhibit-screensaver nil)
        (al:destroy-event-queue event-queue)
        (al:destroy-display display)
        (al:stop-samples)
        (al:uninstall-system)
        (al:uninstall-audio)
        (al:shutdown-ttf-addon)
        (al:shutdown-font-addon)
        (al:shutdown-image-addon))))
  0)

(defun main ()
  (#+darwin trivial-main-thread:with-body-in-main-thread #-darwin progn nil
    (float-features:with-float-traps-masked
        (:divide-by-zero :invalid :inexact :overflow :underflow)
      (al:run-main 0 (cffi:null-pointer) (cffi:callback %main)))))

