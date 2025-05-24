#!/usr/bin/env python3

import re
import json
import sys

def parse_proof_output(output):
    """
    Parse GetProof.sh output and return structured data
    """
    result = {
        "block_number": "N/A",
        "proof": "N/A",
        "status": "ERROR",
        "error": ""
    }
    
    if not output or not output.strip():
        result["error"] = "Empty output from GetProof.sh"
        return result
    
    try:
        # Extract block number
        block_match = re.search(r'Номер блока:\s*(\d+)', output)
        if block_match:
            result["block_number"] = block_match.group(1)
        
        # Extract proof data (handle multiline)
        proof_match = re.search(r'Proof:\s*(.+)', output, re.DOTALL)
        if proof_match:
            # Clean up the proof data - remove newlines and extra spaces
            proof_data = proof_match.group(1).strip()
            proof_data = re.sub(r'\s+', '', proof_data)  # Remove all whitespace
            result["proof"] = proof_data
        
        # Check if both values were found
        if result["block_number"] != "N/A" and result["proof"] != "N/A":
            result["status"] = "SUCCESS"
        else:
            result["error"] = f"Missing data - Block: {result['block_number']}, Proof: {'Found' if result['proof'] != 'N/A' else 'Missing'}"
            
    except Exception as e:
        result["error"] = f"Parsing error: {str(e)}"
    
    return result

def main():
    if len(sys.argv) != 2:
        print(json.dumps({
            "block_number": "ERROR",
            "proof": "ERROR", 
            "status": "FAILED",
            "error": "Usage: parse_proof.py <output_text>"
        }))
        sys.exit(1)
    
    output = sys.argv[1]
    result = parse_proof_output(output)
    print(json.dumps(result))

if __name__ == "__main__":
    main() 
