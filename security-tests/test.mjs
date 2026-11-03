import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,deleteDoc,collection,query,where,getDocs,Timestamp} from 'firebase/firestore';
import {readFileSync} from 'node:fs';
const env=await initializeTestEnvironment({projectId:'demo-icebreaker',firestore:{host:'127.0.0.1',port:8188,rules:readFileSync('../firestore.rules','utf8')}});
const a=env.authenticatedContext('alice').firestore(),b=env.authenticatedContext('bob').firestore(),e=env.authenticatedContext('eve').firestore(),anon=env.unauthenticatedContext().firestore();
const chat={participantIds:['alice','bob'],participantNames:['Alice','Bob'],lastActivity:Timestamp.now(),lastMessage:'',lastMessageSenderId:'',typingUsers:[],unreadCounts:{alice:0,bob:0}};
const msg={senderId:'alice',text:'Hello',timestamp:Timestamp.now(),deliveryStatus:'sent',isRead:false};
let count=0;async function check(name,fn){await fn();console.log('PASS '+name);count++;}
try{
await env.withSecurityRulesDisabled(async c=>{const db=c.firestore();await setDoc(doc(db,'users/alice'),{uid:'alice',isVisible:false});await setDoc(doc(db,'users/bob'),{uid:'bob',isVisible:true});await setDoc(doc(db,'conversations/c1'),chat);await setDoc(doc(db,'conversations/c1/messages/m1'),msg);});
await check('anonymous denied',()=>assertFails(getDoc(doc(anon,'users/bob'))));
await check('private profile denied',()=>assertFails(getDoc(doc(e,'users/alice'))));
await check('owner reads profile',()=>assertSucceeds(getDoc(doc(a,'users/alice'))));
await check('visible profile query works',()=>assertSucceeds(getDocs(query(collection(e,'users'),where('isVisible','==',true)))));
await check('other profile edits denied',()=>assertFails(updateDoc(doc(e,'users/alice'),{firstName:'fake'})));
await check('owner profile edits work',()=>assertSucceeds(updateDoc(doc(a,'users/alice'),{firstName:'Alice'})));
await check('outsider conversation denied',()=>assertFails(getDoc(doc(e,'conversations/c1'))));
await check('participant query works',()=>assertSucceeds(getDocs(query(collection(a,'conversations'),where('participantIds','array-contains','alice')))));
await check('outsider messages denied',()=>assertFails(getDoc(doc(e,'conversations/c1/messages/m1'))));
await check('participant messages allowed',()=>assertSucceeds(getDoc(doc(b,'conversations/c1/messages/m1'))));
await check('outsider sending denied',()=>assertFails(setDoc(doc(e,'conversations/c1/messages/x'),{...msg,senderId:'eve'})));
await check('forged sender denied',()=>assertFails(setDoc(doc(b,'conversations/c1/messages/x'),msg)));
await check('legitimate send works',()=>assertSucceeds(setDoc(doc(a,'conversations/c1/messages/m2'),msg)));
await check('message rewriting denied',()=>assertFails(updateDoc(doc(a,'conversations/c1/messages/m1'),{text:'edited'})));
await check('recipient read receipt works',()=>assertSucceeds(updateDoc(doc(b,'conversations/c1/messages/m1'),{isRead:true,deliveryStatus:'read'})));
await check('participant replacement denied',()=>assertFails(updateDoc(doc(a,'conversations/c1'),{participantIds:['alice','eve']})));
await check('typing update works',()=>assertSucceeds(updateDoc(doc(a,'conversations/c1'),{typingUsers:['alice']})));
await check('message metadata works',()=>assertSucceeds(updateDoc(doc(a,'conversations/c1'),{lastMessage:'Hello',lastMessageSenderId:'alice','unreadCounts.bob':1,lastActivity:Timestamp.now()})));
await check('new conversation works',()=>assertSucceeds(setDoc(doc(a,'conversations/new'),chat)));
await check('outsider cannot create chat for others',()=>assertFails(setDoc(doc(e,'conversations/forged'),chat)));
await check('unknown collections denied',()=>assertFails(setDoc(doc(a,'secrets/x'),{x:1})));
await check('connection request works',()=>assertSucceeds(setDoc(doc(a,'connections/c1'),{fromUserId:'alice',toUserId:'bob',status:'pending',createdAt:Timestamp.now(),type:'connection_request'})));
await check('outsider connection denied',()=>assertFails(getDoc(doc(e,'connections/c1'))));
await check('recipient accepts connection',()=>assertSucceeds(updateDoc(doc(b,'connections/c1'),{status:'accepted'})));
await check('participant can delete chat messages',()=>assertSucceeds(deleteDoc(doc(a,'conversations/c1/messages/m2'))));
console.log(`${count} security checks passed`);
}finally{await env.cleanup();}
