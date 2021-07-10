import requests
import json
import argparse

parser = argparse.ArgumentParser(description='Output .sh filename.')
parser.add_argument('filepath',action='store')
args = parser.parse_args()
filepath = args.filepath
modified = []
noreleases = ["No latest/release with this url:\n"]
updateflag = False
with open(filepath) as fp:
  line = fp.readline()
  cnt = 0
  path = "https://api.github.com/repos/"
  requestpath = ''
  islatest = False

  while line:
    l = line.strip() #remove tab, spaces..
    if l.startswith('github_url="https://github.com/'):
      requestpath = path+l[31:-5]+"/releases/latest"
      #print("Line {}: {}".format(cnt, requestpath))

    if l.startswith('tag_version'):
      #send url request
      r = requests.get(requestpath)
      try:
        tag_version = r.json()['tag_name']
        islatest = (tag_version == l[13:-1])
        print("Line {}: {}".format(cnt, requestpath))

        #update the tags if curr tag != latest
        if(islatest):
          print("This tag is the latest\n")
        else:
          line = '\ttag_version="{}"\n'.format(tag_version)
          print("Tag name updated from {} to {}: \n".format(l[13:-1],tag_version))
          updateflag=True
        
      #this api does not have latest/releases.
      except:
        temp = requestpath+"\n"
        noreleases.append(temp)

    modified.append(line)
    line = fp.readline()
    cnt += 1
fp.close()

#print the api that do not have latest/releases
for e in noreleases:
  print(e)

if updateflag:
  print('::set-output name=is_updated::true')
  outF = open(filepath, "w")
  for e in modified:
    outF.write(e)
  outF.close()
