from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
import base64
import json
from datetime import datetime
import hashlib
import os

app = Flask(__name__)
CORS(app)

# Configuration
MONGO_URI = "mongodb+srv://kristelmaelim:f9kZiTnEKvL0opnH@cluster0.askdlpq.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"  # Update with your MongoDB URI
API_KEY = "my_super_secret_api_key_123"

client = MongoClient(MONGO_URI)
db = client['medical_records_pre']
records_collection = db['records']
keys_collection = db['keys']

# Predefined Keys (matching the Flutter frontend)
PREDEFINED_KEYS = {
    'public_key': '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwJbF1D3n0E1AmfX2bFHe
4SuKTiVw8B9chDdGW2cqHXqI4obINXaoGlgQObdLpnAM4wHcBCXgjHT1cmu4xMuZ
-----END PUBLIC KEY-----''',
    'private_key': '''-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDAlsXUPefQTUCZ
9fZsUd7hK4pOJXDwH1yEN0ZbZyodeojiZsg1dqgaWBA5t0umcAzjAdwEJeCMdPVy
-----END PRIVATE KEY-----'''
}

# Simple XOR encryption/decryption (matching Flutter frontend)
def encrypt_data(data, key="medical_encryption_key_2024"):
    """Simple XOR encryption matching Flutter implementation"""
    if isinstance(data, str):
        data = data.encode('utf-8')
    
    encrypted = []
    key_bytes = key.encode('utf-8')
    
    for i in range(len(data)):
        encrypted.append(data[i] ^ key_bytes[i % len(key_bytes)])
    
    return base64.b64encode(bytes(encrypted)).decode('utf-8')

def decrypt_data(encrypted_data, key="medical_encryption_key_2024"):
    """Simple XOR decryption matching Flutter implementation"""
    try:
        encrypted_bytes = base64.b64decode(encrypted_data)
        key_bytes = key.encode('utf-8')
        decrypted = []
        
        for i in range(len(encrypted_bytes)):
            decrypted.append(encrypted_bytes[i] ^ key_bytes[i % len(key_bytes)])
        
        return bytes(decrypted).decode('utf-8')
    except Exception as e:
        return f"Decryption error: {str(e)}"

# Enhanced encrypt route for Flutter frontend
@app.route('/encrypt', methods=['POST'])
def encrypt_file():
    """Enhanced encrypt endpoint to work with Flutter frontend"""
    try:
        # Handle both multipart form data and JSON
        if request.is_json:
            data = request.get_json()
            file_id = data.get('file_id')
            owner = data.get('owner')
            patient_name = data.get('patient_name')
            selected_doctor = data.get('selected_doctor')
            encrypted_data = data.get('encrypted_data')  # Already encrypted from Flutter
            public_key = data.get('public_key')
            upload_date = data.get('upload_date')
        else:
            # Handle multipart form data (legacy support)
            file_id = request.form.get('file_id')
            owner = request.form.get('owner')
            patient_name = request.form.get('patient_name', 'Unknown Patient')
            selected_doctor = request.form.get('selected_doctor')
            upload_date = datetime.now().isoformat()
            
            if 'file' in request.files:
                file = request.files['file']
                file_data = file.read().decode('utf-8')
                encrypted_data = encrypt_data(file_data)
            else:
                return jsonify({'error': 'No file or data provided'}), 400
        
        if not all([file_id, owner, encrypted_data]):
            return jsonify({'error': 'file_id, owner, and encrypted_data required'}), 400
        
        # Create record
        record = {
            'file_id': file_id,
            'owner': owner,
            'patient_name': patient_name or 'Unknown Patient',
            'selected_doctor': selected_doctor,
            'encrypted_data': encrypted_data,
            'upload_date': upload_date or datetime.now().isoformat(),
            'access_grants': [owner],  # Owner always has access
            'access_requests': [],
            'access_status': 'uploaded',
            'public_key': public_key or PREDEFINED_KEYS['public_key']
        }
        
        # Store in MongoDB
        records_collection.replace_one({'file_id': file_id}, record, upsert=True)
        
        return jsonify({
            'file_id': file_id,
            'message': 'File encrypted and stored successfully',
            'upload_date': record['upload_date']
        })
        
    except Exception as e:
        return jsonify({'error': f'Encryption failed: {str(e)}'}), 500

# New route for doctors to view available documents
@app.route('/doctor-documents', methods=['POST'])
def get_doctor_documents():
    """Get documents available to a specific doctor"""
    try:
        data = request.get_json()
        doctor_id = data.get('doctor_id')
        
        if not doctor_id:
            return jsonify({'error': 'doctor_id required'}), 400
        
        # Find documents where this doctor was selected
        documents = records_collection.find({
            'selected_doctor': doctor_id
        })
        
        doc_list = []
        for doc in documents:
            # Determine access status
            access_status = 'Pending'
            if doctor_id in doc.get('access_grants', []):
                access_status = 'Granted'
            elif doctor_id in doc.get('access_requests', []):
                access_status = 'Requested'
            
            doc_info = {
                'file_id': doc['file_id'],
                'patient_name': doc.get('patient_name', 'Unknown Patient'),
                'upload_date': doc.get('upload_date', 'Unknown'),
                'access_status': access_status,
                'owner': doc['owner']
            }
            doc_list.append(doc_info)
        
        # Sort by upload date (newest first)
        doc_list.sort(key=lambda x: x.get('upload_date', ''), reverse=True)
        
        return jsonify({
            'documents': doc_list,
            'count': len(doc_list)
        })
        
    except Exception as e:
        return jsonify({'error': f'Failed to fetch documents: {str(e)}'}), 500

# Enhanced request access route
@app.route('/request-access', methods=['POST'])
def request_access():
    """Doctor requests access to a medical record"""
    try:
        data = request.get_json()
        file_id = data.get('file_id')
        doctor = data.get('doctor')
        patient_name = data.get('patient_name', '')
        
        if not file_id or not doctor:
            return jsonify({'error': 'file_id and doctor required'}), 400
        
        # Check if record exists
        record = records_collection.find_one({'file_id': file_id})
        if not record:
            return jsonify({'error': 'Record not found'}), 404
        
        # Check if doctor is the selected doctor for this document
        if record.get('selected_doctor') != doctor:
            return jsonify({'error': 'You are not authorized to access this document'}), 403
        
        # Add to access requests if not already requested
        result = records_collection.update_one(
            {'file_id': file_id},
            {'$addToSet': {'access_requests': doctor}}
        )
        
        if result.matched_count == 0:
            return jsonify({'error': 'Record not found'}), 404
        
        return jsonify({
            'message': f'Access request submitted for {patient_name}\'s document',
            'file_id': file_id,
            'doctor': doctor
        })
        
    except Exception as e:
        return jsonify({'error': f'Request access failed: {str(e)}'}), 500

# Enhanced grant access route
@app.route('/grant-access', methods=['POST'])
def grant_access():
    """Patient grants access to doctor"""
    try:
        data = request.get_json()
        file_id = data.get('file_id')
        doctor = data.get('doctor')
        owner = data.get('owner')
        
        if not all([file_id, doctor, owner]):
            return jsonify({'error': 'file_id, doctor, and owner required'}), 400
        
        # Get record and verify ownership
        record = records_collection.find_one({'file_id': file_id})
        if not record or record['owner'] != owner:
            return jsonify({'error': 'Record not found or unauthorized'}), 403
        
        # Update record to grant access
        result = records_collection.update_one(
            {'file_id': file_id},
            {
                '$addToSet': {'access_grants': doctor},
                '$pull': {'access_requests': doctor}  # Remove from requests
            }
        )
        
        if result.matched_count == 0:
            return jsonify({'error': 'Record not found'}), 404
        
        return jsonify({
            'message': f'Access granted to Dr. {doctor}',
            'file_id': file_id
        })
        
    except Exception as e:
        return jsonify({'error': f'Grant access failed: {str(e)}'}), 500

# Enhanced decrypt route
@app.route('/decrypt', methods=['POST'])
def decrypt_file():
    """Decrypt medical record for authorized users"""
    try:
        data = request.get_json()
        file_id = data.get('file_id')
        requester = data.get('requester')
        api_key = data.get('api_key')
        private_key = data.get('private_key')
        
        # Verify API key
        if api_key != API_KEY:
            return jsonify({'error': 'Invalid API key'}), 401
        
        if not file_id or not requester:
            return jsonify({'error': 'file_id and requester required'}), 400
        
        # Get record
        record = records_collection.find_one({'file_id': file_id})
        if not record:
            return jsonify({'error': 'Record not found'}), 404
        
        # Check access permissions
        if requester not in record.get('access_grants', []):
            return jsonify({'error': 'Access denied. Request access first.'}), 403
        
        # Decrypt the data
        encrypted_data = record.get('encrypted_data')
        if not encrypted_data:
            return jsonify({'error': 'No encrypted data found'}), 404
        
        # Decrypt using our simple XOR method
        try:
            decrypted_content = decrypt_data(encrypted_data)
            
            # Return the decrypted content (already base64 encoded for Flutter)
            return jsonify({
                'encrypted_data': encrypted_data,  # Return encrypted for Flutter to decrypt client-side
                'decrypted_data': base64.b64encode(decrypted_content.encode('utf-8')).decode('utf-8'),
                'file_id': file_id,
                'requester': requester,
                'message': 'File decrypted successfully'
            })
            
        except Exception as decrypt_error:
            return jsonify({'error': f'Decryption failed: {str(decrypt_error)}'}), 500
        
    except Exception as e:
        return jsonify({'error': f'Decrypt operation failed: {str(e)}'}), 500

# Enhanced view requests route
@app.route('/view-requests', methods=['POST'])
def view_requests():
    """View access requests for patient's records"""
    try:
        data = request.get_json()
        owner = data.get('owner')
        
        if not owner:
            return jsonify({'error': 'owner required'}), 400
        
        # Find all records owned by this patient
        owned_records = records_collection.find({'owner': owner})
        result = {}
        
        for record in owned_records:
            file_id = record['file_id']
            requests = record.get('access_requests', [])
            if requests:  # Only include files with pending requests
                result[file_id] = requests
        
        return jsonify(result)
        
    except Exception as e:
        return jsonify({'error': f'Failed to fetch requests: {str(e)}'}), 500

# New route to get system statistics
@app.route('/stats', methods=['GET'])
def get_stats():
    """Get system statistics"""
    try:
        total_records = records_collection.count_documents({})
        total_requests = records_collection.count_documents({'access_requests': {'$ne': []}})
        
        return jsonify({
            'total_records': total_records,
            'pending_requests': total_requests,
            'status': 'healthy'
        })
        
    except Exception as e:
        return jsonify({'error': f'Stats unavailable: {str(e)}'}), 500

# Initialize predefined keys in database
@app.route('/initialize-keys', methods=['POST'])
def initialize_keys():
    """Initialize system with predefined keys"""
    try:
        # Store predefined keys
        key_record = {
            'system_keys': True,
            'public_key': PREDEFINED_KEYS['public_key'],
            'private_key': PREDEFINED_KEYS['private_key'],
            'created_at': datetime.now().isoformat()
        }
        
        keys_collection.replace_one({'system_keys': True}, key_record, upsert=True)
        
        return jsonify({
            'message': 'System keys initialized',
            'public_key': PREDEFINED_KEYS['public_key'][:50] + '...'
        })
        
    except Exception as e:
        return jsonify({'error': f'Key initialization failed: {str(e)}'}), 500

# Health check with enhanced info
@app.route('/health', methods=['GET'])
def health_check():
    try:
        # Test database connection
        db_status = "connected"
        record_count = records_collection.count_documents({})
        
        return jsonify({
            'status': 'healthy',
            'message': 'Enhanced Medical Records API is running',
            'database': db_status,
            'total_records': record_count,
            'api_version': '2.0',
            'features': [
                'document_encryption',
                'access_control',
                'doctor_selection',
                'predefined_keys'
            ]
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500

# CORS preflight handler
@app.before_request
def handle_preflight():
    if request.method == "OPTIONS":
        response = jsonify()
        response.headers.add("Access-Control-Allow-Origin", "*")
        response.headers.add('Access-Control-Allow-Headers', "*")
        response.headers.add('Access-Control-Allow-Methods', "*")
        return response

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    print("Starting Enhanced Medical Records API...")
    print("Features:")
    print("- Document encryption with predefined keys")
    print("- Doctor selection and access control")
    print("- Enhanced security and error handling")
    print("- Compatible with Flutter frontend")
    print("\nAPI Endpoints:")
    print("- POST /encrypt - Upload and encrypt documents")
    print("- POST /doctor-documents - Get available documents for doctor")
    print("- POST /request-access - Request document access")
    print("- POST /grant-access - Grant document access")
    print("- POST /decrypt - Decrypt authorized documents")
    print("- POST /view-requests - View pending access requests")
    print("- GET /health - Health check")
    print("- POST /initialize-keys - Initialize system keys")
    
    app.run(host='0.0.0.0', port=5000, debug=True)