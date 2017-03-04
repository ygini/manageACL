#!/usr/bin/swift

import Foundation

let aclDB = ["ba": "list,search,readattr,readextattr,readsecurity,limit_inherit",
             "ro": "list,search,readattr,readextattr,readsecurity,file_inherit,directory_inherit",
             "rw": "list,add_file,search,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,readsecurity,file_inherit,directory_inherit",
             "fc": "list,add_file,search,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,readsecurity,writesecurity,chown,file_inherit,directory_inherit"]

let aclExplaination : [String : String]
let summaryFile : String

if let currentLanguageCode = Locale.current.languageCode, currentLanguageCode == "fr" {
    summaryFile = "droits.txt"
    aclExplaination = ["ba": "accès en lecture seule sans héritage",
                       "ro": "lecture seule sur le dossier et les sous dossiers",
                       "rw": "lecture et écriture sur le dossier et les sous dossiers",
                       "fc": "contrôle complet sur le dossier et les sous dossiers"]
    
} else {
    summaryFile = "rights.txt"
    aclExplaination = ["ba": "read access without inheritence",
                       "ro": "read access on folder and subfolders",
                       "rw": "read and write access on folder and subfolders",
                       "fc": "full control on folder and subfolders"]
}

let configFile = ".rights.plist"
let bashFile = ".rights.sh"

var allGeneratedBashFiles = [String]()

func summaryFileFor(baseFolder: String, sharePoint: String) -> String {
    return baseFolder+"/"+sharePoint+"/"+summaryFile
}

func bashFileFor(baseFolder: String, sharePoint: String) -> String {
    return baseFolder+"/"+sharePoint+"/"+bashFile
}

func configFileFor(baseFolder: String, sharePoint: String) -> String {
    return baseFolder+"/"+sharePoint+"/"+configFile
}

func groupExist(_ group: String) -> Bool {
    let task = Process.init()
    task.launchPath = "/usr/bin/dscl"
    task.arguments = ["/Search", "read", "/Groups/"+group]
    task.standardError = Pipe()
    task.standardOutput = Pipe()
    task.launch()
    task.waitUntilExit()
    
    return task.terminationStatus == 0
}


func userExist(_ user: String) -> Bool {
    let task = Process.init()
    task.launchPath = "/usr/bin/dscl"
    task.arguments = ["/Search", "read", "/Users/"+user]
    task.standardError = Pipe()
    task.standardOutput = Pipe()
    task.launch()
    task.waitUntilExit()
    
    return task.terminationStatus == 0
}

func printACLSummary(_ baseFolder: String, sharePoint: String) {
    print(getACLSummary(baseFolder, sharePoint:sharePoint))
}

func printAllACLSummary(_ baseFolder: String) {
    do {
        for sharePoint in try FileManager.default.contentsOfDirectory(atPath: baseFolder) {
            printACLSummary(baseFolder, sharePoint: sharePoint)
        }
    } catch {
        print("Error, we got exception when printing all breif files for base folder "+baseFolder)
    }
    
}


func writeACLSummary(_ baseFolder: String, sharePoint: String) {
    print("Writting résumé for "+sharePoint)
    let brief = getACLSummary(baseFolder, sharePoint:sharePoint)
    
    let sharePointPath = baseFolder+"/"+sharePoint
    let briefFilePath = sharePointPath+"/"+summaryFile
    
    do {
        try brief.write(toFile: briefFilePath, atomically: true, encoding: String.Encoding.utf8)
        
        print("Brief file written at: "+briefFilePath)
    } catch {
        print("Error, impossible to write brief at path: "+briefFilePath)
    }
}



func writeAllACLSummary(_ baseFolder: String) {
    print("Writting résumé for all share points")
    do {
        for sharePoint in try FileManager.default.contentsOfDirectory(atPath: baseFolder) {
            writeACLSummary(baseFolder, sharePoint: sharePoint)
        }
    } catch {
        print("Error, we got exception when writing all breif files for base folder "+baseFolder)
    }
    
}



func getACLSummary(_ baseFolder: String, sharePoint: String) -> String {
    let sharePointPath = baseFolder+"/"+sharePoint
    let configFilePath = configFileFor(baseFolder: baseFolder, sharePoint: sharePoint)
    
    var isDirectory: ObjCBool = ObjCBool(false)
    var fileExist = FileManager.default.fileExists(atPath: sharePointPath, isDirectory: &isDirectory)
    
    guard fileExist && isDirectory.boolValue else {
        print("Error, share point does not exist: '"+sharePointPath+"'")
        return ""
    }
    
    fileExist = FileManager.default.fileExists(atPath: configFilePath, isDirectory: &isDirectory)
    
    guard fileExist && !isDirectory.boolValue else {
        print("Error: configuration file does not exist: '"+configFilePath+"'")
        return ""
    }
    
    guard let rights = NSDictionary(contentsOfFile: configFilePath) as? [String: [String: String]] else {
        print("Error: impossible to read configuration file: '"+configFilePath+"'")
        return ""
    }
    
    var brief = "Access rights for root items in "+sharePoint+" sharepoint are:\n"
    //var brief = "Les droits d'accès pour les éléments racines du partage "+sharePoint+" sont :\n"
    
    for subFolder in rights.keys {
        brief += "- For "+subFolder+"\n"
        //brief += "- Pour "+subFolder+"\n"
        
        let targetFolder = sharePointPath+"/"+subFolder
        
        fileExist = FileManager.default.fileExists(atPath: targetFolder, isDirectory: &isDirectory)
        guard fileExist && isDirectory.boolValue else {
            print("Error, folder doesn't exist or is not a directory: '"+targetFolder+"'")
            return ""
        }
        
        guard let acl = rights[subFolder]! as [String: String]? else {
            print("Impossible to get ACL for '"+subFolder+"'")
            return ""
        }
        
        for rightHolder in acl.keys {
            guard let right = acl[rightHolder] else {
                print("Error, impossible error")
                return ""
            }
            
            let rightHolderInfo: String? = {
                if groupExist(rightHolder) {
                    return "Group "+rightHolder
                    //return "Le groupe "+rightHolder
                } else if userExist(rightHolder) {
                    return "User "+rightHolder
                    //return "L'utilisateur "+rightHolder
                } else {
                    print("User ID not known: "+rightHolder)
                    return ""
                }
            }()
            
            
            if let rightHolderInfo = rightHolderInfo {
                guard let explainedRight = aclExplaination[right] else {
                    print("Error: impossible to convert '"+right+"' into system ACL")
                    return ""
                }
                
                brief += "- - "+rightHolderInfo+" has "+explainedRight+"\n"
                //brief += "- - "+rightHolderInfo+" en "+explainedRight+"\n"
                
            }
            
        }
    }
    
    return brief
}

func generateBashFile(_ baseFolder: String, sharePoint: String) {
    print("Creating access rights script for "+sharePoint)
    let sharePointPath = baseFolder+"/"+sharePoint
    let configFilePath = configFileFor(baseFolder: baseFolder, sharePoint: sharePoint)
    let bashScriptPath = bashFileFor(baseFolder: baseFolder, sharePoint: sharePoint)
    
    var groupsForSharePointAccess = [String]()
    var finalBashContent = "chflags -R nouchg \"" + sharePointPath + "\" \n"
    finalBashContent += "chmod -RN \"" + sharePointPath + "\" \n"
    
    var isDirectory: ObjCBool = ObjCBool(false)
    var fileExist = FileManager.default.fileExists(atPath: sharePointPath, isDirectory: &isDirectory)
    
    guard fileExist && isDirectory.boolValue else {
        print("Error: share point does not exist: '"+sharePointPath+"'")
        return
    }
    
    fileExist = FileManager.default.fileExists(atPath: configFilePath, isDirectory: &isDirectory)
    
    guard fileExist && !isDirectory.boolValue else {
        print("Error: configuration file does not exist: '"+configFilePath+"'")
        return
    }
    
    guard let rights = NSDictionary(contentsOfFile: configFilePath) as? [String: [String: String]] else {
        print("Error: impossible to read configuration file: '"+configFilePath+"'")
        return
    }
    
    for subFolder in rights.keys {
        
        let targetFolder = sharePointPath+"/"+subFolder
        
        fileExist = FileManager.default.fileExists(atPath: targetFolder, isDirectory: &isDirectory)
        guard fileExist && isDirectory.boolValue else {
            return
        }
        
        guard let acl = rights[subFolder]! as [String: String]? else {
            return
        }
        
        for rightHolder in acl.keys {
            guard let right = acl[rightHolder] else {
                print("Error: impossible error")
                return
            }
            
            let rightHolderForChmod: String? = {
                if groupExist(rightHolder) {
                    return "group:"+rightHolder
                } else if userExist(rightHolder) {
                    return "user:"+rightHolder
                } else {
                    return nil
                }
            }()
            
            
            if let rightHolderForChmod = rightHolderForChmod {
                guard let finalACL = aclDB[right] else {
                    print("Error: impossible to convert '"+right+"' into system ACL")
                    return
                }
                
                finalBashContent += "chmod +a \"" + rightHolderForChmod + " allow " + finalACL + "\" \"" + targetFolder + "\" \n"
                
                groupsForSharePointAccess.append(rightHolder)
            }
            
        }
    }
    
    for rightHolder in groupsForSharePointAccess {
        let rightHolderForChmod: String? = {
            if groupExist(rightHolder) {
                return "group:"+rightHolder
            } else if userExist(rightHolder) {
                return "user:"+rightHolder
            } else {
                return nil
            }
        }()
        
        
        if let rightHolderForChmod = rightHolderForChmod {
            guard let finalACL = aclDB["ba"] else {
                print("Error: impossible to get base access ACL")
                return
            }
            
            finalBashContent += "chmod +a \"" + rightHolderForChmod + " allow " + finalACL + "\" \"" + sharePointPath + "\" \n"
        }
    }
    
    finalBashContent += "/Applications/Server.app/Contents/ServerRoot/usr/share/servermgrd/bundles/servermgr_sharing.bundle/Contents/copyprivs  -p \"" + sharePointPath + "\" -f 32 -s $(mktemp -t createTeamSharePoint)\n"
    
    do {
        try finalBashContent.write(toFile: bashScriptPath, atomically: true, encoding: String.Encoding.utf8)
        allGeneratedBashFiles.append(bashScriptPath)
        
        let task = Process.init()
        task.launchPath = "/bin/chmod"
        task.arguments = ["+x", bashScriptPath]
        task.standardError = Pipe()
        task.standardOutput = Pipe()
        task.launch()
        task.waitUntilExit()
        
        print("Bash file written at: "+bashScriptPath)
    } catch {
        print("Error, impossible to write bash file at "+bashScriptPath)
    }
}

func generateAllBashFiles(_ baseFolder: String) {
    print("Deploying access rights for all share points")
    do {
        for sharePoint in try FileManager.default.contentsOfDirectory(atPath: baseFolder) {
            generateBashFile(baseFolder, sharePoint: sharePoint)
        }
    } catch {
        print("Error, exception catched when generating all bash file")
    }
}

func addRight(_ baseFolder: String, sharePoint: String, subFolder: String, rightHolder: String, right: String) {
    print("Add "+rightHolder+" in "+right+" for "+sharePoint+"/"+subFolder)
    guard (aclDB[right] != nil) else {
        print("Error, impossible to convert '"+right+"' into system ACL")
        return
    }
    
    guard groupExist(rightHolder) || userExist(rightHolder) else {
        print("Error, impossible to find right holder: '"+rightHolder+"'")
        return
    }
    
    let sharePointPath = baseFolder+"/"+sharePoint
    let configFilePath = configFileFor(baseFolder: baseFolder, sharePoint: sharePoint)
    
    
    var isDirectory: ObjCBool = ObjCBool(false)
    let fileExist = FileManager.default.fileExists(atPath: sharePointPath, isDirectory: &isDirectory)
    
    guard fileExist && isDirectory.boolValue else {
        return
    }
    
    var configTmp = NSDictionary(contentsOfFile: configFilePath) as? [String: [String: String]]
    
    if configTmp == nil {
        configTmp = [String: [String: String]]()
    }
    
    guard var config = configTmp else {
        return
    }
    
    if config[subFolder] == nil {
        config[subFolder] = [String: String]()
    }
    
    config[subFolder]![rightHolder] = right
    
    
    let finalConfig = config as NSDictionary
    finalConfig.write(toFile: configFilePath, atomically: true)
    
}

func removeRight(_ baseFolder: String, sharePoint: String, subFolder: String, rightHolder: String) {
    print("Remove "+rightHolder+" from "+sharePoint+"/"+subFolder)
    guard groupExist(rightHolder) || userExist(rightHolder) else {
        print("Error, impossible to find right holder: '"+rightHolder+"'")
        return
    }
    
    let sharePointPath = baseFolder+"/"+sharePoint
    let configFilePath = configFileFor(baseFolder: baseFolder, sharePoint: sharePoint)
    
    
    var isDirectory: ObjCBool = ObjCBool(false)
    let fileExist = FileManager.default.fileExists(atPath: sharePointPath, isDirectory: &isDirectory)
    
    guard fileExist && isDirectory.boolValue else {
        return
    }
    
    var configTmp = NSDictionary(contentsOfFile: configFilePath) as? [String: [String: String]]
    
    if configTmp == nil {
        configTmp = [String: [String: String]]()
    }
    
    guard var config = configTmp else {
        return
    }
    
    if config[subFolder] == nil {
        config[subFolder] = [String: String]()
    }
    
    config[subFolder]![rightHolder] = nil
    
    
    let finalConfig = config as NSDictionary
    finalConfig.write(toFile: configFilePath, atomically: true)
    
}



func cron(baseFolder: String) {
    print("Run from cron, checking updated config to be deployed")
    do {
        for sharePoint in try FileManager.default.contentsOfDirectory(atPath: baseFolder) {
            if sharePoint.hasPrefix(".") {
                continue
            }
            print("Check date change between config and bash file for "+sharePoint)
            let configPath = configFileFor(baseFolder: baseFolder, sharePoint: sharePoint)
            let bashPath = bashFileFor(baseFolder: baseFolder, sharePoint: sharePoint)
            if let configModificationDate = try FileManager.default.attributesOfItem(atPath: configPath)[FileAttributeKey.modificationDate] as! Date?,
                let bashModificationDate = try FileManager.default.attributesOfItem(atPath: bashPath)[FileAttributeKey.modificationDate] as! Date? {
                if (configModificationDate > bashModificationDate) {
                    print("Update needed for "+sharePoint)
                    generateBashFile(baseFolder, sharePoint: sharePoint)
                    writeACLSummary(baseFolder, sharePoint: sharePoint)
                } else {
                    print("No update needed for "+sharePoint)
                }
            }
        }
    } catch {
        print("Error, exception catched when looking for updated config")
        print(error)
    }
    
    runAllUpdatedScripts()
}

func runAllUpdatedScripts() {
    for bashFile in allGeneratedBashFiles {
        print("Execute bash script "+bashFile)
        let task = Process.init()
        task.launchPath = "/bin/bash"
        task.arguments = [bashFile]
        task.standardError = Pipe()
        task.standardOutput = Pipe()
        task.launch()
        task.waitUntilExit()
    }
}


func printHelp() {
    print("manageACL")
    print("")
    print("This tool offer a standard way to manage ACL for sharepoint.")
    print("It will create configuration file for expected rights and")
    print("allow you to clear all permissions and start again when needed.")
    print("")
    print("To use this tool you must store all your managed sharepoint in the same folder,")
    print("you need one sharepoint per goal with specific subfolders per access rights in it.")
    print("")
    print("Typical use case look like:")
    print("- All sharepoint located at /Volumes/DataHD/Sharing/Managed")
    print("- One sharepoint per team or subject (Board, Accounting, IT, Building…)")
    print("- Each sharepoint has subfolder per access right scope (Management, Internal, Exchange, Public…)")
    print("")
    print("You will use manageACL to specify rights for subfolders per sharepoint (Management in Accounting).")
    print("This tool will add requested right to the subfolder (Management) for the requested right holder (user or group)")
    print("and also add basic access to the share point (Accounting).")
    print("")
    print("Available rights are:")
    for right in aclExplaination.keys {
        print("- "+right+": "+aclExplaination[right]!)
    }
    print("")
    print("Supported syntax and operations:")
    print("")
    print("manageACL -baseFolder <base folder path> -operation deploy")
    print("manageACL -baseFolder <base folder path> -operation deploy -sharePoint <share point name>")
    print("\t Will remove all existing right and deploy rights using config file.")
    print("\t Summary file will be updated at the end")
    print("")
    print("manageACL -baseFolder <base folder path> -operation summary")
    print("manageACL -baseFolder <base folder path> -operation summary -sharePoint <share point name>")
    print("\t Will update summary file according to the config (not to the effective right)")
    print("\t You should not start this operation directly but use deploy")
    print("")
    print("manageACL -baseFolder <base folder path> -operation print")
    print("manageACL -baseFolder <base folder path> -operation print -sharePoint <share point name>")
    print("\t Print to the shell the rights according to the config (not to the effective right)")
    print("")
    print("manageACL -baseFolder <base folder path> -operation add -sharePoint <share point name> -subFolder <subfolder> -rightHolder <user or group> -right <ro, rw, fc…>")
    print("\t Add requested right to the config file (but does not deploy it)")
    print("")
    print("manageACL -baseFolder <base folder path> -operation remove -sharePoint <share point name> -subFolder <subfolder> -rightHolder <user or group>")
    print("\t Remove requested right to the config file (but does not deploy it)")
    print("")
    print("manageACL -baseFolder <base folder path> -operation cron")
    print("\t Run deploy command only if config changed since last deploy (based on update date for "+configFile+" and "+bashFile+"))")
}

func main() {
    if geteuid() != 0{
        print("This tool must be run as root.")
        exit(1)
    }
    
    guard let baseFolder = UserDefaults.standard.string(forKey: "baseFolder") else {
        print("baseFolder argument is missing")
        print("")
        printHelp()
        return
    }
    
    var isDirectory: ObjCBool = ObjCBool(false)
    let fileExist = FileManager.default.fileExists(atPath: baseFolder, isDirectory: &isDirectory)
    
    guard fileExist && isDirectory.boolValue else {
        print("baseFolder path does not exist or isn't a directory")
        return
    }
    
    guard let operation = UserDefaults.standard.string(forKey: "operation") else {
        print("operation argument is missing")
        print("")
        printHelp()
        return
    }
    
    let sharePoint = UserDefaults.standard.string(forKey: "sharePoint")
    
    switch operation {
    case "deploy":
        if let sharePoint = sharePoint {
            generateBashFile(baseFolder, sharePoint: sharePoint)
            writeACLSummary(baseFolder, sharePoint: sharePoint)
        } else {
            generateAllBashFiles(baseFolder)
            writeAllACLSummary(baseFolder)
        }
	
    case "summary":
        if let sharePoint = sharePoint {
            writeACLSummary(baseFolder, sharePoint: sharePoint)
        } else {
            writeAllACLSummary(baseFolder)
        }
        
    case "print":
        if let sharePoint = sharePoint {
            printACLSummary(baseFolder, sharePoint: sharePoint)
        } else {
            printAllACLSummary(baseFolder)
        }
        
    case "add":
        if let sharePoint = sharePoint,
            let subFolder = UserDefaults.standard.string(forKey: "subFolder"),
            let rightHolder = UserDefaults.standard.string(forKey: "rightHolder"),
            let right = UserDefaults.standard.string(forKey: "right") {
            addRight(baseFolder, sharePoint: sharePoint, subFolder: subFolder, rightHolder: rightHolder, right: right)
        } else {
            print("Missing arguments for remove operation")
            print("")
            printHelp()
        }
        
    case "remove":
        if let sharePoint = sharePoint,
            let subFolder = UserDefaults.standard.string(forKey: "subFolder"),
            let rightHolder = UserDefaults.standard.string(forKey: "rightHolder") {
            removeRight(baseFolder, sharePoint: sharePoint, subFolder: subFolder, rightHolder: rightHolder)
        } else {
            print("Missing arguments for remove operation")
            print("")
            printHelp()
        }
        
    case "cron":
        cron(baseFolder: baseFolder)
        
    default:
        print("Unsupported operation")
        print("")
        printHelp()
    }
    
    runAllUpdatedScripts()
    
    exit (0)
}

main()
