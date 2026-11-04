"""Hash PDS build inputs/options, excluding only tool-written run metadata."""
import hashlib,re

def project_digest(path):
 text=path.read_text('utf8')
 # Preserve quoted strings while finding balanced S-expressions.
 def remove(source,names):
  pattern=r'\((?:'+ '|'.join(names)+r')(?=\s|\))'
  while match:=re.search(pattern,source):
   depth=0;quoted=False;escaped=False
   for end in range(match.start(),len(source)):
    c=source[end]
    if quoted:
     if escaped:escaped=False
     elif c=='\\':escaped=True
     elif c=='"':quoted=False
    elif c=='"':quoted=True
    elif c=='(':depth+=1
    elif c==')':
     depth-=1
     if depth==0:break
   else:raise ValueError('Unbalanced PDS metadata')
   source=source[:match.start()]+source[end+1:]
  return source
 split=text.index('(_task tsk_compile')
 setup=remove(text[:split],['_comment','_timespec'])
 run=remove(text[split:],['_comment','_timespec','_gci_state','_db_output','_output','_input'])
 tokens=re.findall(r'"(?:\\.|[^"\\])*"|[^\s()]+|[()]',setup+run)
 # PDS also rewrites option order into its schema order. Options are keyed
 # configuration values, not an ordered script; retain every name/value and
 # canonicalize only their order within the same parent S-expression.
 stack=[];tree=[]
 for token in tokens:
  if token=='(':
   node=[]
   (stack[-1] if stack else tree).append(node);stack.append(node)
  elif token==')':
   assert stack,'Unexpected closing PDS form'
   stack.pop()
  else:
   assert stack,'Token outside PDS form'
   stack[-1].append(token)
 assert not stack,'Unclosed PDS form'
 def normalize(node):
  for child in node:
   if isinstance(child,list):normalize(child)
  places=[i for i,c in enumerate(node) if isinstance(c,list) and c and c[0]=='_option']
  options=[node[i] for i in places]
  assert len({c[1] for c in options})==len(options),'Duplicate PDS option'
  for i,value in zip(places,sorted(options,key=lambda c:c[1])):node[i]=value
 for node in tree:normalize(node)
 import json
 return hashlib.sha256(json.dumps(tree,ensure_ascii=False,separators=(',',':')).encode('utf8')).hexdigest()
