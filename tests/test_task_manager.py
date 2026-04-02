import json

import task_manager
from conftest import CONTEXT, make_event, seed_task

USER_A = "user-aaa"
USER_B = "user-bbb"


def body(response):
    return json.loads(response["body"])


# ─── routing ─────────────────────────────────────────────────────────────────

class TestRouting:
    def test_unknown_path_returns_404(self, table):
        resp = task_manager.handler(make_event("GET", "/unknown", user_id=USER_A), CONTEXT)
        assert resp["statusCode"] == 404

    def test_method_not_allowed_on_collection(self, table):
        resp = task_manager.handler(make_event("PATCH", "/tasks", user_id=USER_A), CONTEXT)
        assert resp["statusCode"] == 405

    def test_method_not_allowed_on_item(self, table):
        resp = task_manager.handler(
            make_event("POST", "/tasks/some-id", path_params={"id": "some-id"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 405

    def test_missing_task_id_in_path_params(self, table):
        event = make_event("GET", "/tasks/some-id", user_id=USER_A)
        event["pathParameters"] = {}
        resp = task_manager.handler(event, CONTEXT)
        assert resp["statusCode"] == 400


# ─── create ──────────────────────────────────────────────────────────────────

class TestCreateTask:
    def test_success(self, table):
        resp = task_manager.handler(
            make_event("POST", "/tasks", body={"task": "Write tests"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 201
        data = body(resp)
        assert "id" in data
        assert data["task"]["task"] == "Write tests"
        assert data["task"]["status"] == "new"
        assert data["task"]["priority"] == "medium"
        assert data["task"]["user_id"] == USER_A

    def test_custom_status_and_priority(self, table):
        resp = task_manager.handler(
            make_event("POST", "/tasks", body={"task": "Rush", "status": "in_progress", "priority": "urgent"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 201
        assert body(resp)["task"]["status"] == "in_progress"
        assert body(resp)["task"]["priority"] == "urgent"

    def test_missing_task_field(self, table):
        resp = task_manager.handler(make_event("POST", "/tasks", body={}, user_id=USER_A), CONTEXT)
        assert resp["statusCode"] == 400
        assert "task" in body(resp)["message"].lower()

    def test_empty_task_text(self, table):
        resp = task_manager.handler(make_event("POST", "/tasks", body={"task": "   "}, user_id=USER_A), CONTEXT)
        assert resp["statusCode"] == 400

    def test_task_at_max_length(self, table):
        resp = task_manager.handler(
            make_event("POST", "/tasks", body={"task": "x" * 1000}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 201

    def test_task_exceeds_max_length(self, table):
        resp = task_manager.handler(
            make_event("POST", "/tasks", body={"task": "x" * 1001}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400
        assert "1000" in body(resp)["message"]

    def test_invalid_status(self, table):
        resp = task_manager.handler(
            make_event("POST", "/tasks", body={"task": "Task", "status": "banana"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400
        assert "status" in body(resp)["message"].lower()

    def test_invalid_priority(self, table):
        resp = task_manager.handler(
            make_event("POST", "/tasks", body={"task": "Task", "priority": "banana"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400
        assert "priority" in body(resp)["message"].lower()

    def test_invalid_json_body(self, table):
        event = make_event("POST", "/tasks", user_id=USER_A)
        event["body"] = "not-json"
        resp = task_manager.handler(event, CONTEXT)
        assert resp["statusCode"] == 400

    def test_null_body(self, table):
        event = make_event("POST", "/tasks", user_id=USER_A)
        event["body"] = None
        resp = task_manager.handler(event, CONTEXT)
        assert resp["statusCode"] == 400

    def test_all_valid_statuses(self, table):
        for s in ("new", "in_progress", "completed", "cancelled"):
            resp = task_manager.handler(
                make_event("POST", "/tasks", body={"task": f"Task {s}", "status": s}, user_id=USER_A), CONTEXT
            )
            assert resp["statusCode"] == 201, f"status '{s}' should be valid"

    def test_all_valid_priorities(self, table):
        for p in ("low", "medium", "high", "urgent"):
            resp = task_manager.handler(
                make_event("POST", "/tasks", body={"task": f"Task {p}", "priority": p}, user_id=USER_A), CONTEXT
            )
            assert resp["statusCode"] == 201, f"priority '{p}' should be valid"

    def test_response_has_cors_header(self, table):
        resp = task_manager.handler(
            make_event("POST", "/tasks", body={"task": "Task"}, user_id=USER_A), CONTEXT
        )
        assert "Access-Control-Allow-Origin" in resp["headers"]

    def test_task_stored_in_dynamo(self, table):
        resp = task_manager.handler(
            make_event("POST", "/tasks", body={"task": "Persisted"}, user_id=USER_A), CONTEXT
        )
        task_id = body(resp)["id"]
        stored = table.get_item(Key={"id": task_id})
        assert "Item" in stored
        assert stored["Item"]["task"] == "Persisted"


# ─── list ────────────────────────────────────────────────────────────────────

class TestListTasks:
    def test_empty_list(self, table):
        resp = task_manager.handler(make_event("GET", "/tasks", user_id=USER_A), CONTEXT)
        assert resp["statusCode"] == 200
        data = body(resp)
        assert data["count"] == 0
        assert data["items"] == []
        assert data["next"] is None

    def test_returns_only_caller_tasks(self, table):
        seed_task(table, user_id=USER_A, task_text="Mine")
        seed_task(table, user_id=USER_B, task_text="Theirs")
        resp = task_manager.handler(make_event("GET", "/tasks", user_id=USER_A), CONTEXT)
        assert resp["statusCode"] == 200
        data = body(resp)
        assert data["count"] == 1
        assert data["items"][0]["task"] == "Mine"

    def test_invalid_limit(self, table):
        resp = task_manager.handler(
            make_event("GET", "/tasks", query_params={"limit": "abc"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400

    def test_limit_capped_at_100(self, table):
        resp = task_manager.handler(
            make_event("GET", "/tasks", query_params={"limit": "9999"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 200

    def test_invalid_next_token(self, table):
        resp = task_manager.handler(
            make_event("GET", "/tasks", query_params={"next": "!!!not-base64!!!"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400

    def test_pagination_token_is_base64_opaque(self, table):
        import base64
        for i in range(3):
            seed_task(table, user_id=USER_A, task_text=f"Task {i}", offset=i)
        resp = task_manager.handler(
            make_event("GET", "/tasks", query_params={"limit": "2"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 200
        token = body(resp)["next"]
        if token:
            # Must decode cleanly as base64 — no raw DynamoDB attribute types exposed
            decoded = base64.b64decode(token.encode()).decode()
            assert "{" in decoded  # valid JSON
            assert '{"S":' not in decoded  # DynamoDB wire format not exposed

    def test_pagination_next_token_fetches_remaining(self, table):
        for i in range(3):
            seed_task(table, user_id=USER_A, task_text=f"Task {i}", offset=i)
        first = task_manager.handler(
            make_event("GET", "/tasks", query_params={"limit": "2"}, user_id=USER_A), CONTEXT
        )
        token = body(first)["next"]
        assert token is not None
        second = task_manager.handler(
            make_event("GET", "/tasks", query_params={"limit": "2", "next": token}, user_id=USER_A), CONTEXT
        )
        assert second["statusCode"] == 200
        assert body(second)["count"] == 1


# ─── get ─────────────────────────────────────────────────────────────────────

class TestGetTask:
    def test_success(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("GET", f"/tasks/{item['id']}", path_params={"id": item["id"]}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 200
        assert body(resp)["id"] == item["id"]
        assert body(resp)["task"] == item["task"]

    def test_not_found(self, table):
        resp = task_manager.handler(
            make_event("GET", "/tasks/nonexistent", path_params={"id": "nonexistent"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 404

    def test_wrong_owner_returns_404_not_403(self, table):
        """Task existence must never be revealed to unauthorized callers."""
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("GET", f"/tasks/{item['id']}", path_params={"id": item["id"]}, user_id=USER_B), CONTEXT
        )
        assert resp["statusCode"] == 404


# ─── update ──────────────────────────────────────────────────────────────────

class TestUpdateTask:
    def test_update_task_text(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"task": "Updated text"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 200
        assert body(resp)["task"]["task"] == "Updated text"

    def test_update_status(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"status": "completed"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 200
        assert body(resp)["task"]["status"] == "completed"

    def test_update_priority(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"priority": "urgent"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 200
        assert body(resp)["task"]["priority"] == "urgent"

    def test_update_multiple_fields(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"task": "New", "status": "in_progress", "priority": "high"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 200
        updated = body(resp)["task"]
        assert updated["task"] == "New"
        assert updated["status"] == "in_progress"
        assert updated["priority"] == "high"

    def test_update_no_fields_returns_400(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400

    def test_update_empty_task_text(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"task": "   "}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400

    def test_update_task_too_long(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"task": "x" * 1001}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400

    def test_update_invalid_status(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"status": "banana"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400

    def test_update_invalid_priority(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"priority": "banana"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 400

    def test_update_not_found(self, table):
        resp = task_manager.handler(
            make_event("PUT", "/tasks/nonexistent", path_params={"id": "nonexistent"},
                       body={"task": "Updated"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 404

    def test_update_wrong_owner_returns_404(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"task": "Stolen"}, user_id=USER_B), CONTEXT
        )
        assert resp["statusCode"] == 404

    def test_update_returns_updated_at(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("PUT", f"/tasks/{item['id']}", path_params={"id": item["id"]},
                       body={"task": "Updated"}, user_id=USER_A), CONTEXT
        )
        assert "updated_at" in body(resp)["task"]


# ─── delete ──────────────────────────────────────────────────────────────────

class TestDeleteTask:
    def test_success_returns_204(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("DELETE", f"/tasks/{item['id']}", path_params={"id": item["id"]}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 204

    def test_delete_removes_item_from_dynamo(self, table):
        item = seed_task(table, user_id=USER_A)
        task_manager.handler(
            make_event("DELETE", f"/tasks/{item['id']}", path_params={"id": item["id"]}, user_id=USER_A), CONTEXT
        )
        get_resp = task_manager.handler(
            make_event("GET", f"/tasks/{item['id']}", path_params={"id": item["id"]}, user_id=USER_A), CONTEXT
        )
        assert get_resp["statusCode"] == 404

    def test_delete_not_found(self, table):
        resp = task_manager.handler(
            make_event("DELETE", "/tasks/nonexistent", path_params={"id": "nonexistent"}, user_id=USER_A), CONTEXT
        )
        assert resp["statusCode"] == 404

    def test_delete_wrong_owner_returns_404(self, table):
        item = seed_task(table, user_id=USER_A)
        resp = task_manager.handler(
            make_event("DELETE", f"/tasks/{item['id']}", path_params={"id": item["id"]}, user_id=USER_B), CONTEXT
        )
        assert resp["statusCode"] == 404

    def test_delete_does_not_remove_other_users_task(self, table):
        item = seed_task(table, user_id=USER_A)
        task_manager.handler(
            make_event("DELETE", f"/tasks/{item['id']}", path_params={"id": item["id"]}, user_id=USER_B), CONTEXT
        )
        # Item should still exist for USER_A
        get_resp = task_manager.handler(
            make_event("GET", f"/tasks/{item['id']}", path_params={"id": item["id"]}, user_id=USER_A), CONTEXT
        )
        assert get_resp["statusCode"] == 200
