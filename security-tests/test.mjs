import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,deleteDoc,collection,query,where,getDocs,Timestamp,writeBatch} from 'firebase/firestore';
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
await check('legacy visible profile query denied',()=>assertFails(getDocs(query(collection(e,'users'),where('isVisible','==',true)))));
await check('visible private profile direct read denied',()=>assertFails(getDoc(doc(e,'users/bob'))));
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
const publicProfile={schemaVersion:1,isVisible:true,firstName:'Bob',bio:'Hello',interestsText:'art\ncooking',profileImageURL:'',cellLat:1307,cellLon:1060};
if(process.env.SWIFT_PROJECTION_PATH){
 const swiftProjection=JSON.parse(readFileSync(process.env.SWIFT_PROJECTION_PATH,'utf8'));
 await check('actual Swift projection accepted by rules',()=>assertSucceeds(setDoc(doc(b,'discoveryProfiles/bob'),swiftProjection)));
}
await check('owner creates safe discovery profile',()=>assertSucceeds(setDoc(doc(b,'discoveryProfiles/bob'),publicProfile)));
await check('anonymous discovery denied',()=>assertFails(getDoc(doc(anon,'discoveryProfiles/bob'))));
await check('signed-in discovery allowed',()=>assertSucceeds(getDoc(doc(e,'discoveryProfiles/bob'))));
await check('cell range discovery works',()=>assertSucceeds(getDocs(query(collection(e,'discoveryProfiles'),where('cellLat','>=',1300),where('cellLat','<=',1310)))));
for(const field of ['email','latitude','longitude','location','answers','aiAnswers','lastActive']){
 await check('reject shared '+field,()=>assertFails(setDoc(doc(b,'discoveryProfiles/bob'),{...publicProfile,[field]:field==='location'?{latitude:40.7128,longitude:-74.006}:'secret'})));
}
await check('reject fractional latitude cell',()=>assertFails(updateDoc(doc(b,'discoveryProfiles/bob'),{cellLat:1307.12345})));
await check('reject fractional longitude cell',()=>assertFails(updateDoc(doc(b,'discoveryProfiles/bob'),{cellLon:1060.12345})));
await check('reject nested secret in bio',()=>assertFails(updateDoc(doc(b,'discoveryProfiles/bob'),{bio:{email:'private'}})));
await check('outsider cannot edit discovery',()=>assertFails(updateDoc(doc(e,'discoveryProfiles/bob'),{firstName:'fake'})));
await check('cannot hide while leaving shared fields',()=>assertFails(updateDoc(doc(b,'discoveryProfiles/bob'),{isVisible:false})));
await check('legacy visibility-off cannot leave a stale public profile',()=>assertFails(updateDoc(doc(b,'users/bob'),{isVisible:false})));
await check('atomic hide removes public data',async()=>{const batch=writeBatch(b);batch.update(doc(b,'users/bob'),{isVisible:false,isLocationVisible:false});batch.set(doc(b,'discoveryProfiles/bob'),{isVisible:false});await assertSucceeds(batch.commit());});
await check('hidden record contains no profile data',async()=>{const d=(await getDoc(doc(e,'discoveryProfiles/bob'))).data();if(JSON.stringify(d)!==JSON.stringify({isVisible:false}))throw Error('Hidden fields retained');});
await check('hidden profile cannot be republished',()=>assertFails(setDoc(doc(b,'discoveryProfiles/bob'),publicProfile)));
await check('location update stays private',()=>assertSucceeds(updateDoc(doc(b,'users/bob'),{location:{latitude:40.7128,longitude:-74.006},latitude:40.7128,longitude:-74.006})));
await check('atomic show works',async()=>{const batch=writeBatch(b);batch.update(doc(b,'users/bob'),{isVisible:true,isLocationVisible:true});batch.set(doc(b,'discoveryProfiles/bob'),publicProfile);await assertSucceeds(batch.commit());});
await check('legacy private update cannot create extra public fields',async()=>{await assertSucceeds(updateDoc(doc(b,'users/bob'),{email:'private@example.test'}));const d=(await getDoc(doc(e,'discoveryProfiles/bob'))).data();if('email' in d)throw Error('Email exposed');});
await check('delete cannot orphan shared profile',()=>assertFails(deleteDoc(doc(b,'users/bob'))));
await check('atomic delete clears public fields',async()=>{const batch=writeBatch(b);batch.delete(doc(b,'users/bob'));batch.set(doc(b,'discoveryProfiles/bob'),{isVisible:false});await assertSucceeds(batch.commit());});
console.log(`${count} security checks passed`);
}finally{await env.cleanup();}
