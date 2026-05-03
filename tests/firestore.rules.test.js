const fs = require("fs");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

async function runTests() {
  const testEnv = await initializeTestEnvironment({
    projectId: "demo-yallahire",
    firestore: {
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
  });

  await testEnv.clearFirestore();

  const alice = testEnv.authenticatedContext("alice");
  const bob = testEnv.authenticatedContext("bob");

  const aliceDb = alice.firestore();
  const bobDb = bob.firestore();

  console.log("Test 1: Alice can create her own profile");
  await assertSucceeds(
    aliceDb.collection("profiles").doc("alice").set({
      fullName: "Alice",
      isAdmin: false,
    })
  );

  console.log("Test 2: Bob cannot update Alice profile");
  await assertFails(
    bobDb.collection("profiles").doc("alice").update({
      fullName: "Hacked",
    })
  );

  console.log("Test 3: Alice can create her own post");
  await assertSucceeds(
    aliceDb.collection("posts").doc("post1").set({
      title: "Test post",
      postedBy: "alice",
      createdAt: new Date(),
    })
  );

  console.log("Test 4: Bob cannot delete Alice post");
  await assertFails(
    bobDb.collection("posts").doc("post1").delete()
  );

  console.log("All Firestore security rules tests passed.");

  await testEnv.cleanup();
}

runTests().catch((error) => {
  console.error("Test failed:", error);
  process.exit(1);
});