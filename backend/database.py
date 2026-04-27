import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, Column, Integer, String, Float, select
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.exc import IntegrityError

load_dotenv()

# URL in file .env 
DB_USER = os.getenv("DATABASE_URL")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME")
DB_PORT = os.getenv("DB_PORT", "5432")
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}"

# إنشاء المحرك وSession
engine = create_engine(DATABASE_URL, echo=True, future=True)
SessionLocal = sessionmaker(bind=engine, future=True)

Base = declarative_base()

# جدول Equipment
class Equipment(Base):
    __tablename__ = "equipment"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, unique=True)
    type = Column(String)
    status = Column(String, default="available")
    productivity_factor = Column(Float, default=1.0)

# إنشاء الجداول 
def create_tables():
    Base.metadata.create_all(engine)
    print("Tables created successfully ")

# إضافة بيانات اختبارية    
def insert_sample_data():
    session = SessionLocal()
    try:
        # تحقق إذا البيانات موجودة
        eq_check = session.execute(select(Equipment).where(Equipment.name=="Crane A")).first()
        if not eq_check:
            eq1 = Equipment(name="Crane A", type="Crane", status="available", productivity_factor=1.0)
            session.add(eq1)
        
        eq_check2 = session.execute(select(Equipment).where(Equipment.name=="Bulldozer B")).first()
        if not eq_check2:
            eq2 = Equipment(name="Bulldozer B", type="Bulldozer", status="in_use", productivity_factor=0.8)
            session.add(eq2)

        session.commit()
        print("Sample data inserted ")
    except IntegrityError:
        session.rollback()
        print("Data already exists, skipped insertion ")
    finally:
        session.close()

if __name__ == "__main__":
    create_tables()
    insert_sample_data()