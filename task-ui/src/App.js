import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { v4 as uuidv4 } from 'uuid';

const API_URL = 'https://711mli5ga4.execute-api.us-east-1.amazonaws.com/dev/tasks';

function App() {
  const [tasks, setTasks] = useState([]);
  const [newTask, setNewTask] = useState('');

  const fetchTasks = async () => {
    try {
      const response = await axios.get(API_URL);
      setTasks(response.data.tasks || []);
    } catch (err) {
      console.error('Error fetching tasks:', err);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!newTask.trim()) return;

    try {
      await axios.post(API_URL, {
        id: uuidv4(),
        task: newTask.trim()
      });
      setNewTask('');
      fetchTasks();
    } catch (err) {
      console.error('Error creating task:', err);
    }
  };

  useEffect(() => {
    fetchTasks();
  }, []);

  return (
    <div style={{ maxWidth: '500px', margin: '40px auto', fontFamily: 'sans-serif' }}>
      <h1>Task Manager</h1>

      <form onSubmit={handleSubmit}>
        <input
          type="text"
          value={newTask}
          placeholder="Enter a task"
          onChange={(e) => setNewTask(e.target.value)}
          style={{ width: '70%', padding: '8px' }}
        />
        <button type="submit" style={{ padding: '8px 12px', marginLeft: '8px' }}>Add</button>
      </form>

      <ul style={{ marginTop: '20px' }}>
        {tasks.map((t, idx) => (
          <li key={idx} style={{ padding: '4px 0' }}>{typeof t === 'string' ? t : t.task}</li>
        ))}
      </ul>
    </div>
  );
}

export default App;

