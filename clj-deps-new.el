;;; clj-deps-new.el --- Create clojure projects from templates  -*- lexical-binding: t; -*-

;; Copyright (C) 2021  jpe90

;; Author: jpe90 <eskinjp@gmail.com>
;; URL: https://github.com/jpe90/emacs-deps-new
;; Version: 1.0
;; Package-Requires: ((emacs "25.1" ) (transient "0.3.7"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This is a small wrapper around the deps.new tool for creating deps.edn
;; Clojure projects from templates.
;;
;; It provides access to built-in and some additional commmunity deps.new and
;; clj-new templates via `clj-deps-new'. The command displays a series of
;; on-screen prompts allowing the user to interactively select arguments,
;; preview their output, and create projects.
;;
;; You can also create transient prefixes and suffixes to access your own custom
;; templates. (see https://github.com/jpe90/emacs-deps-new#extending)
;; 
;; It requires external utilities 'tools.build', 'deps.new', and 'clj-new' to be
;; installed. See https://github.com/seancorfield/deps-new for installation
;; instructions.
;; 
;; Requires transient.el to be loaded.

;;; Code:

(require 'transient)

(defcustom clj-deps-new-clj-new-alias
  "clj-new"
  "The Clojure CLI tools alias referring to the clj-new tool. You can find this
by running \"clojure -Ttools list\" or in your user deps.edn, depending on how
you installed it."
  :type 'string
  :safe #'stringp)

(defcustom clj-deps-new-deps-new-alias
  "new"
  "The Clojure CLI tools alias referring to the clj-new tool. You can find this
by running \"clojure -Ttools list\" or in your user deps.edn, depending on how
you installed it."
  :type 'string
  :safe #'stringp)

(defclass transient-quoted-option (transient-option) ()
  "Class used for escaping text entered by a user to opts for the deps-new cmd.")

(cl-defmethod transient-infix-value ((obj transient-quoted-option))
  "Shell-quote the VALUE in OBJ specified on TRANSIENT-QUOTED-OPTION."
  (let ((value (oref obj value))
        (arg (oref obj argument)))
    (concat arg (shell-quote-argument value))))

(defun clj-deps-new--assemble-command (command alias name opts)
  "Helper function for building the deps.new command string.
COMMAND: string name of the deps.new command
NAME: a string consisting of the keyword :name followed by the project name
OPTS: keyword - string pairs provided to the template by the user"
  (concat "clojure -T" alias " " command " " name " " (mapconcat #'append opts " ")))

;; This macro generates prefixes and suffixes for each of the built-in
;; deps.new commands. A macro was chosen over writing out the prefixes and
;; suffixes separately because they share nearly identical arguments, and the macro
;; significantly cuts down on boilerplate.
;;
;; When adding your own commands, it's recommended to add prefixes and suffixes
;; separately and not use this macro.
(defmacro clj-deps-new-def--transients (arglist)
  "Create the prefix and suffix transients for the built-in deps.new commands.
ARGLIST: a plist of values that are substituted into the macro."
  `(progn
     (transient-define-suffix ,(intern (format "execute-%s"  (plist-get arglist :name))) (&optional opts)
       ,(format "Create the %s" (plist-get arglist :name))
       :key "c"
       :description ,(plist-get arglist :description)
       (interactive (list (transient-args transient-current-command)))
       (let* ((name (read-string ,(plist-get arglist :prompt)))
              (display-name (concat ":name " (shell-quote-argument name)))
              (command (clj-deps-new--assemble-command ,(plist-get arglist :name) ,clj-deps-new-deps-new-alias display-name opts)))
         (message "Executing command `%s' in %s" command default-directory)
         (shell-command command)))
     (transient-define-prefix ,(intern (format "new-%s"  (plist-get arglist :name))) ()
       ,(format "Create a new %s" (plist-get arglist :name))
       ["Opts"
        ("-d" "Alternate project folder name (relative path, no trailing slash)" ":target-dir " :class transient-quoted-option)
        ("-o" "Don't overwrite existing projects" ":overwrite false" :class transient-switch)]
       ["Actions"
        (,(intern (format "execute-%s"  (plist-get arglist :name))))])))

(clj-deps-new-def--transients (:name "app" :description "Create an Application" :prompt "Application name: "))
(clj-deps-new-def--transients (:name "lib" :description "Create a Library" :prompt "Library name: "))
(clj-deps-new-def--transients (:name "template" :description "Create a Template" :prompt "Template name: "))
(clj-deps-new-def--transients (:name "scratch" :description "Create a Minimal \"scratch\" Project" :prompt "Scratch name: "))
(clj-deps-new-def--transients (:name "pom" :description "Create a pom.xml file" :prompt "Project name: "))

;; This transient prefix references transient prefixes for built-in deps.new
;; commands generated by the macro. When adding your own custom commands,
;; you should append additional transients to this prefix.
(transient-define-prefix clj-deps-new ()
  "Generate a project using deps.new."
  ["Select a generation template"
   ("a" "Application" new-app)
   ("l" "Library" new-lib)
   ("t" "Template" new-template)
   ("s" "Scratch" new-scratch)
   ("p" "pom.xml" new-pom)])

(provide 'clj-deps-new)
;;; clj-deps-new.el ends here
