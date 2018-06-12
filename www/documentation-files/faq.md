# FAQ


### How do I change my password?  
At the moment there is no way to change your password using the website or command-line. Please contact contact@haxe.org with the emailaddress of your account.  

---

### How to use `haxelib` on the command line   
Check out [using haxelib](/documentation/using-haxelib/).  

---

### Can a project have multiple contributors?
Yes, just add multiple usernames in the contributors list (`"contributors": ["Juraj","Jason","Nicolas"],`) and make a new release. This will allow multiple users to submit.

---

### How do I transfer ownership of a haxelib?  
Haxelib only sees contributors, so you can add the new "owner" and remove the old one and make a new release.  

---

### How to make a haxelib.json file?  
Check out [creating a haxelib package](/documentation/creating-a-haxelib-package/). 

---

### How do I validate my haxelib.json file?  
If you want to be sure if the haxelib json file is correct, try using `haxelib submit`. This will validate if the data is correct. Press ctrl+c to terminate the actual submission.  

---

### How do I get a readme/changelog/license tab on my haxelib project page?  
Add a "README.md", "CHANGELOG.md" and/or "LICENSE.md" markdown file in your zip file that is submitted.

---

### Why doesn't my project have stats graph?  
The project stats graph is only shown when the project has more than one release.

---

### How do I remove my haxelib?  
At the moment there is no way to remove a library from the registry, because this could break existing projects. If there serious issues like vulnerabilities or copyright infringements, please contact contact@haxe.orgs with the emailaddress of your account.  

---

### Where can I report haxelib issues? 
Go to <https://github.com/HaxeFoundation/haxelib/issues>.
