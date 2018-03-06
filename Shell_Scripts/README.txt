The two scripts in this directory are taken from a project
wherein I want to be able to reliably recreate the Linux
environment on my BeagleBone.  The setupViaUSB.exp script
will create a tarball of install packages and config files,
transfer them onto the BeagleBone, then it runs
QuailSetup.bash, which does the bulk of the setup: installing
package updates, disabling services, and compiling the
library source code that I will be linking against.
