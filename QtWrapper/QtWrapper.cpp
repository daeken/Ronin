// This is the main DLL file.

#include "QtWrapper.h"

#pragma unmanaged
#include <QtGui/QtGui>
#include <QtScript/QtScript>
#pragma managed

#include <msclr/marshal.h>
#include <msclr/marshal_cppstd.h>

using namespace System;
using namespace System::Collections::Generic;
using namespace System::Runtime::InteropServices;
using namespace msclr::interop;

namespace QtWrapper {
	QScriptValue FuncWrapper(QScriptContext *context, QScriptEngine *engine);
	QScriptValue ParentGetter(QScriptContext *context, QScriptEngine *engine);
	QScriptValue SignalsForSlot(QScriptContext *context, QScriptEngine *engine);
	
	void RegisterPatch();
	CRITICAL_SECTION CriticalSection;
	
	public ref class NamedTuple {
	public:
		QObject *Obj;
		String ^Name;
		
		NamedTuple(QObject *obj, String ^name) {
			Obj = obj;
			Name = name;
		}
	};
	
	ref class QObjectWrapper;
	QObjectWrapper ^WrapQObject(QScriptValue obj);
	QScriptValue GetQObject(Object ^obj);
	ref class Variant;
	Variant ^WrapQVariant(QScriptValue obj);
	
	public ref class QtScript {
	public:
		QScriptEngine *engine;
		static QtScript ^inst;
		Dictionary <NamedTuple ^, List <NamedTuple ^> ^> ^ConnectionMapping;
		QEventLoop *loop;
		
		QtScript() {
			inst = this;
			engine = new QScriptEngine();
			loop = new QEventLoop();
			ConnectionMapping = gcnew Dictionary <NamedTuple ^, List <NamedTuple ^> ^>();
			engine->globalObject().setProperty("signalsForSlot", engine->newFunction(SignalsForSlot));
			engine->globalObject().setProperty("parentOf", engine->newFunction(ParentGetter));
		}
		
		void SetupPatches() {
			RegisterPatch();
		}
		
		static Object ^ObjectFromSVal(QScriptValue value) {
			if(value.isNumber())
				return safe_cast <Object ^>(value.toInt32());
			else if(value.isString())
				return StringFromQStr(value.toString());
			else if(value.isBool())
				return value.toBool();
			else if(value.isArray()) {
				QScriptValueIterator it(value);
				int count = 0;
				while(it.hasNext()) {
					++count;
					it.next();
				}
				it.toFront();
				array <Object ^>^ arr = gcnew array <Object ^>(count);
				count = 0;
				while(it.hasNext()) {
					it.next();
					arr[count++] = ObjectFromSVal(it.value());
				}
				return arr;
			} else if(value.isQObject()) {
				return WrapQObject(value);
			} else if(value.isVariant()) {
				return WrapQVariant(value);
			} else
				return nullptr;
		}
		
		QScriptValue SValFromObject(Object ^obj) {
			if(obj == nullptr)
				return QScriptValue::NullValue;
			Type ^t = obj->GetType();
			if(t == Int32::typeid)
				return QScriptValue(engine, (int) safe_cast <int ^>(obj));
			else if(t->IsArray) {
				array <Object ^> ^arr = safe_cast <array <Object ^>>(obj);
				QScriptValue val = engine->newArray(arr->Length);
				for(int i = 0; i < arr->Length; ++i)
					val.setProperty(i, SValFromObject(arr[i]));
				return val;
			} else if(t == String::typeid)
				return QScriptValue(engine, QStrFromString(safe_cast <String ^>(obj)));
			else if(t == Boolean::typeid)
				return QScriptValue(engine, safe_cast <bool>(obj));
			else if(t == IntPtr::typeid)
				return engine->newQObject((QObject *) (safe_cast <IntPtr ^>(obj)->ToPointer()));
			else if(t == Delegate::typeid)
				return WrapFunction(safe_cast <Delegate ^>(obj));
			else if(t == QObjectWrapper::typeid)
				return GetQObject(obj);
			return QScriptValue::NullValue;
		}
		
		static QString QStrFromString(String ^str) {
			char *chars = (char *) (void *) Marshal::StringToHGlobalAnsi(str);
			QString qstr = QString::fromAscii(chars, str->Length);
			Marshal::FreeHGlobal((System::IntPtr) (void *) chars);
			
			return qstr;
		}
		
		static String ^StringFromQStr(QString str) {
			QByteArray latin = str.toLatin1();
			return marshal_as <String ^>(latin.constData());
		}
		
		Object ^Evaluate(String ^code) {
			QScriptValue val = engine->evaluate(QStrFromString(code));
			
			return ObjectFromSVal(val);
		}
		
		Object ^Invoke(String ^name, Object ^args) {
			QScriptValue func = engine->globalObject().property(QStrFromString(name));
			QScriptValue val = func.call(engine->globalObject(), SValFromObject(args));
			
			return ObjectFromSVal(val);
		}
		
		IntPtr ^WidgetFromHandle(IntPtr ^handle) {
			return gcnew IntPtr((void *) QWidget::find((HWND) handle->ToPointer()));
		}
		
		void ExposeFunction(String ^name, Delegate ^dele) {
			engine->globalObject().setProperty(QStrFromString(name), WrapFunction(dele));
		}
		
		QScriptValue WrapFunction(Delegate ^dele) {
			QScriptValue func = engine->newFunction(FuncWrapper);
			func.setProperty("func", (uint) (void *) GCHandle::ToIntPtr(GCHandle::Alloc(dele)));
			return func;
		}
		
		void Connection(const QObject *sender, const char *signal, const QObject *receiver, const char *slot) {
			String ^msignal = marshal_as <String ^>(++signal);
			String ^mslot = marshal_as <String ^>(++slot);
			
			List <NamedTuple ^> ^list = nullptr;
			for each(NamedTuple ^key in ConnectionMapping->Keys) {
				if(key->Obj == receiver && key->Name == mslot) {
					list = ConnectionMapping[key];
					break;
				}
			}
			if(list == nullptr) {
				list = gcnew List <NamedTuple ^>();
				ConnectionMapping[gcnew NamedTuple((QObject *) receiver, mslot)] = list;
			}
			list->Add(gcnew NamedTuple((QObject *) sender, msignal));
		}
		
		void Log(char *foo) {
			array <String ^> ^params = gcnew array <String ^>(1);
			params[0] = marshal_as <String ^>(foo);
			
			Invoke("log", params);
		}
		
		void ProcessEvents() {
			//QCoreApplication::processEvents();
			loop->processEvents();
		}
	};
	
	public ref class QObjectWrapper {
	public:
		QScriptValue *Obj;
		
		QObjectWrapper(QScriptValue *obj) {
			Obj = obj;
		}
		
		property Object ^default[String ^] {
			Object ^get(String ^name) {
				return QtScript::ObjectFromSVal(Obj->property(QtScript::QStrFromString(name)));
			}
		}
		
		Object ^Invoke(String ^name, ...array <Object ^> ^params) {
			QScriptValue func = Obj->property(QtScript::QStrFromString(name));
			QScriptValue val = func.call(QtScript::inst->engine->globalObject(), QtScript::inst->SValFromObject(params));
			return QtScript::inst->ObjectFromSVal(val);
		}
		
		bool Connect(String ^name, Delegate ^dele) {
			QScriptValue func = QtScript::inst->WrapFunction(dele);
			name = String::Concat("2", name);
			char *chars = (char *) (void *) Marshal::StringToHGlobalAnsi(name);
			chars[name->Length] = 0;
			bool ret = qScriptConnect(Obj->toQObject(), chars, QScriptValue::NullValue, func);
			Marshal::FreeHGlobal((System::IntPtr) (void *) chars);
			return ret;
		}
	};
	
	QScriptValue GetQObject(Object ^obj) {
		return *(safe_cast <QObjectWrapper ^>(obj)->Obj);
	}
	
	QObjectWrapper ^WrapQObject(QScriptValue obj) {
		return gcnew QObjectWrapper(new QScriptValue(obj));
	}
	
	public ref class Variant {
	public:
		QVariant *Obj;
		
		Variant(QVariant *obj) {
			Obj = obj;
		}
		
		int ToInt() {
			return *(int *) Obj->data();
		}
	};
	
	Variant ^WrapQVariant(QScriptValue obj) {
		return gcnew Variant(new QVariant(obj.toVariant()));
	}
	
	QScriptValue SignalsForSlot(QScriptContext *context, QScriptEngine *engine) {
		QObject *obj = context->argument(0).toQObject();
		String ^slot = QtScript::StringFromQStr(context->argument(1).toString());
		QScriptEngine *engine_ = QtScript::inst->engine;
		
		QScriptValue ret = engine_->newArray(0);
		
		int i = 0;
		for each(KeyValuePair <NamedTuple ^, List <NamedTuple ^> ^> ^kv in QtScript::inst->ConnectionMapping) {
			if(kv->Key->Obj == obj && kv->Key->Name == slot) {
				for each(NamedTuple ^elem in kv->Value) {
					QScriptValue arr = engine_->newArray(2);
					arr.setProperty(0, engine_->newQObject(elem->Obj));
					arr.setProperty(1, QScriptValue(QtScript::inst->QStrFromString(elem->Name)));
					ret.setProperty(i++, arr);
				}
				
				break;
			}
		}
		
		return ret;
	}
	
	QScriptValue FuncWrapper(QScriptContext *context, QScriptEngine *engine) {
		QScriptValue callee = context->callee();
		Delegate ^dele = safe_cast <Delegate ^>(GCHandle::FromIntPtr((IntPtr) (void *) callee.property("func").toUInt32()).Target);
		
		array <Object ^> ^paramarr = gcnew array <Object ^>(context->argumentCount());
		for(int i = 0; i < paramarr->Length; ++i)
			paramarr[i] = QtScript::ObjectFromSVal(context->argument(i));
		Object ^ret = dele->DynamicInvoke(paramarr);
		
		return QtScript::inst->SValFromObject(ret);
	}
	
	QScriptValue ParentGetter(QScriptContext *context, QScriptEngine *engine) {
		return engine->newQObject(context->argument(0).toQObject()->parent());
	}
	
	void __cdecl redirectedConnect(void *ignore1, const QObject *sender, const char *signal, const QObject *receiver, const char *slot, Qt::ConnectionType type) {
		EnterCriticalSection(&CriticalSection);
		QtScript::inst->Connection(sender, signal, receiver, slot);
		LeaveCriticalSection(&CriticalSection);
	}
	
	__declspec(naked) void _patchqconnect() {
		__asm {
			call redirectedConnect;
			push 0xCAFEBABE;
			push 0x6711CBC9;
			push 0xDEADBEEF;
			ret;
		}
	}
	
	void PatchPatch(void *orig) {
		void *addr = &_patchqconnect;
		void *base = (void *) ((DWORD) addr & 0xFFFFF000U);
		DWORD old;
		VirtualProtect(base, 0x2000, PAGE_READWRITE, &old);
		
		unsigned char *func = (unsigned char *) addr;
		*((DWORD *) (func + 6)) = 0xFFFFFFFF;
		*((DWORD *) (func + 16)) = (DWORD) orig + 7;
		
		VirtualProtect(base, 0x2000, old, NULL);
	}
	
	void RegisterPatch() {
		void *addr = GetProcAddress(LoadLibrary(L"QtCore4.dll"), "?connect@QObject@@SA_NPBV1@PBD01W4ConnectionType@Qt@@@Z");
		PatchPatch(addr);
		
		void *base = (void *) ((DWORD) addr & 0xFFFFF000U);
		DWORD old;
		VirtualProtect(base, 0x2000, PAGE_READWRITE, &old);
		
		unsigned char *func = (unsigned char *) addr;
		func[0] = 0xE9;
		*(DWORD *) (func + 1) = ((DWORD) &_patchqconnect) - ((DWORD) addr + 5);
		
		VirtualProtect(base, 0x2000, old, NULL);
		
		FlushInstructionCache(GetCurrentProcess(), base, 0x2000);
		
		InitializeCriticalSectionAndSpinCount(&CriticalSection, 0x80000400);
	}
}
