# manageACL

This tool offer a standard way to manage ACL for sharepoint.
It will create configuration file for expected rights and
allow you to clear all permissions and start again when needed.

To use this tool you must store all your managed sharepoint in the same folder,
you need one sharepoint per goal with specific subfolders per access rights in it.

Typical use case look like:
- All sharepoint located at /Volumes/DataHD/Sharing/Managed
- One sharepoint per team or subject (Board, Accounting, IT, Building…)
- Each sharepoint has subfolder per access right scope (Management, Internal, Exchange, Public…)

You will use manageACL to specify rights for subfolders per sharepoint (Management in Accounting).
This tool will add requested right to the subfolder (Management) for the requested right holder (user or group)
and also add basic access to the share point (Accounting).

##Available rights are:
- rw: read and write access on folder and subfolders
- ba: read access without inheritence
- ro: read access on folder and subfolders
- fc: full control on folder and subfolders

##Supported syntax and operations:

manageACL -baseFolder <base folder path> -operation deploy
manageACL -baseFolder <base folder path> -operation deploy -sharePoint <share point name>
	 Will remove all existing right and deploy rights using config file.
	 Summary file will be updated at the end

manageACL -baseFolder <base folder path> -operation summary
manageACL -baseFolder <base folder path> -operation summary -sharePoint <share point name>
	 Will update summary file according to the config (not to the effective right)
	 You should not start this operation directly but use deploy

manageACL -baseFolder <base folder path> -operation print
manageACL -baseFolder <base folder path> -operation print -sharePoint <share point name>
	 Print to the shell the rights according to the config (not to the effective right)

manageACL -baseFolder <base folder path> -operation add -sharePoint <share point name> -subFolder <subfolder> -rightHolder <user or group> -right <ro, rw, fc…>
	 Add requested right to the config file (but does not deploy it)

manageACL -baseFolder <base folder path> -operation remove -sharePoint <share point name> -subFolder <subfolder> -rightHolder <user or group>
	 Remove requested right to the config file (but does not deploy it)

manageACL -baseFolder <base folder path> -operation cron
	 Run deploy command only if config changed since last deploy (based on update date for .rights.plist and .rights.sh))
