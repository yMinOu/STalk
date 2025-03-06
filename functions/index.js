const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.database();

// 매 5분마다 실행되는 함수: 1시간 이전에 종료된 세션 삭제
exports.cleanOldSessions = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async (context) => {
    try {
      const threshold = Date.now() - 1 * 60 * 60 * 1000; // 1시간 전
      const roomsSnapshot = await db.ref("rooms").once("value");

      if (!roomsSnapshot.exists()) {
        console.log("No rooms data found.");
        return null;
      }

      const rooms = roomsSnapshot.val();
      const deletionPromises = [];

      // 각 방(Room)을 순회
      Object.entries(rooms).forEach(([roomKey, sessions]) => {
        if (sessions) {
          // 각 세션(Session)을 순회
          Object.entries(sessions).forEach(([sessionKey, sessionData]) => {
            if (sessionData.terminated) {
              const sessionTimestamp = Number(sessionKey);
              if (!isNaN(sessionTimestamp) && sessionTimestamp < threshold) {
                const deletePath = `rooms/${roomKey}/${sessionKey}`;
                console.log(`Deleting session ${sessionKey} in room ${roomKey}`);
                deletionPromises.push(db.ref(deletePath).remove());
              }
            }
          });
        }
      });

      // 병렬 삭제 처리
      await Promise.all(deletionPromises);
      console.log(`Cleanup completed: ${deletionPromises.length} sessions deleted.`);
      return null;
    } catch (error) {
      console.error("Error cleaning old sessions:", error);
      return null;
    }
  });
