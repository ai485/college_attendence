/**
 * Dashboard frontend logic.
 * Handles session management, attendance polling, and manual approvals.
 */
(function () {
    'use strict';

    let activeSessionId = null;
    let pollInterval = null;

    const elSubject = document.getElementById('subject');
    const elRoom = document.getElementById('room');
    const elBtnStart = document.getElementById('btn-start');
    const elBtnStop = document.getElementById('btn-stop');
    const elSessionStatus = document.getElementById('session-status');
    const elStatPresent = document.getElementById('stat-present');
    const elStatPending = document.getElementById('stat-pending');
    const elStatManual = document.getElementById('stat-manual');
    const elAttendanceList = document.getElementById('attendance-list');
    const elManualList = document.getElementById('manual-requests-list');

    // ─── Load Rooms ─────────────────────────────────────────
    async function loadRooms() {
        try {
            const res = await fetch('/api/rooms');
            const data = await res.json();
            elRoom.innerHTML = '<option value="">Select Room...</option>';
            data.rooms.forEach(r => {
                const opt = document.createElement('option');
                opt.value = r.room_number;
                opt.textContent = r.room_number;
                elRoom.appendChild(opt);
            });
        } catch (e) {
            console.error('Failed to load rooms:', e);
        }
    }

    // ─── Check Active Session ───────────────────────────────
    async function checkActiveSession() {
        try {
            const res = await fetch('/api/session/active');
            const data = await res.json();
            if (data.active) {
                setActive(data.session_id, data.subject, data.room_number);
            }
        } catch (e) {
            console.error('Failed to check session:', e);
        }
    }

    function setActive(sessionId, subject, room) {
        activeSessionId = sessionId;
        elSessionStatus.innerHTML = `<span class="badge badge-active">🟢 Active: ${subject} | Room ${room} | ID: ${sessionId}</span>`;
        elBtnStart.disabled = true;
        elBtnStop.disabled = false;
        startPolling();
    }

    function setInactive() {
        activeSessionId = null;
        elSessionStatus.innerHTML = '<span class="badge badge-inactive">No Active Session</span>';
        elBtnStart.disabled = false;
        elBtnStop.disabled = true;
        stopPolling();
        elStatPresent.textContent = '0';
        elStatPending.textContent = '0';
        elStatManual.textContent = '0';
        elAttendanceList.innerHTML = '<p class="empty-msg">Start a session to see attendance.</p>';
        elManualList.innerHTML = '<p class="empty-msg">No pending requests.</p>';
    }

    // ─── Start/Stop Session ─────────────────────────────────
    document.getElementById('start-session-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const subject = elSubject.value.trim();
        const room = elRoom.value;
        if (!subject || !room) return;

        try {
            const res = await fetch('/api/session/start', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ subject, room_number: room })
            });
            const data = await res.json();
            if (data.error) {
                alert(data.error);
                return;
            }
            setActive(data.session_id, subject, room);
        } catch (e) {
            alert('Failed to start session');
        }
    });

    elBtnStop.addEventListener('click', async () => {
        if (!confirm('Stop the current session?')) return;
        try {
            await fetch('/api/session/stop', { method: 'POST' });
            setInactive();
        } catch (e) {
            alert('Failed to stop session');
        }
    });

    // ─── Polling ────────────────────────────────────────────
    function startPolling() {
        if (pollInterval) return;
        pollData();
        pollInterval = setInterval(pollData, 3000);
    }

    function stopPolling() {
        if (pollInterval) {
            clearInterval(pollInterval);
            pollInterval = null;
        }
    }

    async function pollData() {
        if (!activeSessionId) return;

        try {
            // Fetch attendance
            const aRes = await fetch(`/api/attendance/list?session_id=${activeSessionId}`);
            const aData = await aRes.json();

            let present = 0, pending = 0;
            const items = aData.attendance || [];

            items.forEach(a => {
                if (a.status === 'present' || a.status === 'manual_approved') present++;
                else pending++;
            });

            elStatPresent.textContent = present;
            elStatPending.textContent = pending;

            if (items.length === 0) {
                elAttendanceList.innerHTML = '<p class="empty-msg">No students verified yet.</p>';
            } else {
                elAttendanceList.innerHTML = items.map(a => {
                    const statusClass = (a.status === 'present' || a.status === 'manual_approved')
                        ? 'status-present'
                        : a.status === 'manual_requested' ? 'status-manual' : 'status-pending';
                    return `
                        <div class="list-item">
                            <div class="item-info">
                                <strong>${a.student_name}</strong>
                                <span class="item-detail">ID: ${a.student_id} | Status: <span class="${statusClass}">${a.status}</span></span>
                            </div>
                            <div class="item-detail">${a.marked_at || ''}</div>
                        </div>`;
                }).join('');
            }

            // Fetch manual requests
            const mRes = await fetch(`/api/attendance/manual-requests?session_id=${activeSessionId}`);
            const mData = await mRes.json();
            const manuals = mData.requests || [];

            elStatManual.textContent = manuals.length;

            if (manuals.length === 0) {
                elManualList.innerHTML = '<p class="empty-msg">No pending requests.</p>';
            } else {
                elManualList.innerHTML = manuals.map(m => `
                    <div class="list-item">
                        <div class="item-info">
                            <strong>🙋 ${m.student_name}</strong>
                            <span class="item-detail">ID: ${m.student_id} | Reason: ${m.reason || 'N/A'}</span>
                        </div>
                        <div class="item-actions">
                            <button class="btn btn-sm btn-success" onclick="approveManual(${m.id}, true)">✅ Approve</button>
                            <button class="btn btn-sm btn-danger" onclick="approveManual(${m.id}, false)">❌ Reject</button>
                        </div>
                    </div>
                `).join('');
            }
        } catch (e) {
            console.error('Poll error:', e);
        }
    }

    // ─── Manual Approve/Reject (global) ─────────────────────
    window.approveManual = async function (requestId, approved) {
        try {
            await fetch('/api/attendance/approve-manual', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ request_id: requestId, approved })
            });
            pollData();
        } catch (e) {
            alert('Failed to process request');
        }
    };

    // ─── Init ───────────────────────────────────────────────
    loadRooms();
    checkActiveSession();
})();
