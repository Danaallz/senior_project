from database import SessionLocal, Equipment
from fastapi import FastAPI
from sqlalchemy.orm import Session
from fastapi import Depends
from pydantic import BaseModel

app = FastAPI()

@app.get("/")
def home():
    return {"message": "Backend is working "}

# Dependency عشان نفتح session ونقفلها بأمان
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Endpoint جديد يعرض المعدات من PostgreSQL
@app.get("/equipment")
def get_equipment(db: Session = Depends(get_db)):
    return db.query(Equipment).all()

class EquipmentCreate(BaseModel):
    name: str
    type: str
    status: str
    productivity_factor: float


@app.post("/equipment")
def create_equipment(equipment: EquipmentCreate, db: Session = Depends(get_db)):
    new_equipment = Equipment(**equipment.dict())
    db.add(new_equipment)
    db.commit()
    db.refresh(new_equipment)
    return new_equipment

@app.delete("/equipment/{equipment_id}")
def delete_equipment(equipment_id: int, db: Session = Depends(get_db)):
    equipment = db.query(Equipment).filter(Equipment.id == equipment_id).first()
    if not equipment:
        return {"error": "Not found"}
    
    db.delete(equipment)
    db.commit()
    return {"message": "Deleted successfully"}


