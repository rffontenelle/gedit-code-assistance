namespace Gcp.C
{

class TranslationUnit
{
	private Mutex d_lock;
	private Mutex d_slock;
	private Cond d_cond;
	private bool d_exit;
	private bool d_tainted;
	private string? d_source;
	private string[]? d_args;
	private unowned Thread<void *> d_thread;
	private unowned CX.Index? d_index;

	private CX.TranslationUnit d_tu;

	private UnsavedFile[]? d_unsaved;

	public signal void update();

	public delegate void WithTranslationUnitCallback(CX.TranslationUnit tu);

	public TranslationUnit()
	{
		d_lock = new Mutex();
		d_slock = new Mutex();
		d_cond = new Cond();

		d_unsaved = null;
		d_exit = false;
		d_tainted = false;
		d_source = null;
		d_args = null;
		d_index = null;

		try
		{
			d_thread = Thread.create<void *>(reparse_thread, true);
		}
		catch
		{
			d_thread = null;
		}
	}

	~TranslationUnit()
	{
		if (d_thread == null)
		{
			return;
		}

		d_slock.lock();
		d_exit = true;
		d_cond.signal();
		d_slock.unlock();

		d_thread.join();
	}

	public bool tainted
	{
		get
		{
			d_lock.lock();
			bool ret = d_tainted;
			d_lock.unlock();

			return ret;
		}
		set
		{
			d_lock.lock();
			d_tainted = value;
			d_lock.unlock();
		}
	}

	public void with_translation_unit(WithTranslationUnitCallback callback)
	{
		if (tainted)
		{
			MainContext ctx = MainContext.get_thread_default();
			bool exitit = false;

			while (!exitit)
			{
				ctx.iteration(true);

				d_lock.lock();
				exitit = !d_tainted;

				if (exitit)
				{
					callback(d_tu);
				}

				d_lock.unlock();
			}

			return;
		}
		else
		{
			d_lock.lock();
			callback(d_tu);
			d_lock.unlock();
		}
	}

	public void *reparse_thread()
	{
		while (true)
		{
			d_slock.lock();

			if (d_unsaved == null)
			{
				d_cond.wait(d_slock);
			}

			if (d_exit)
			{
				d_slock.unlock();
				break;
			}

			UnsavedFile[] uf = (owned)d_unsaved;
			d_unsaved = null;
			d_slock.unlock();

			d_lock.lock();

			if (d_index != null && d_source != null && d_args != null)
			{
				d_tu = new CX.TranslationUnit(d_index,
				                              d_source,
				                              d_args,
				                              (CX.UnsavedFile[])uf);

				d_index = null;
				d_source = null;
				d_args = null;
			}
			else
			{
				d_tu.reparse((CX.UnsavedFile[])uf);
			}

			d_tainted = false;
			d_lock.unlock();

			Idle.add(() => {
				update();
				return false;
			});
		}

		return null;
	}

	public void parse(CX.Index idx,
	                  string source,
	                  string[] args,
	                  UnsavedFile[]? unsaved)
	{
		d_slock.lock();

		d_unsaved = unsaved;
		d_index = idx;
		d_source = source;
		d_args = args;

		d_cond.signal();
		d_slock.unlock();
	}

	public void reparse(UnsavedFile[] ?unsaved = null)
	{
		d_slock.lock();
		d_unsaved = unsaved;
		d_cond.signal();
		d_slock.unlock();
	}
}

}

/* vi:ex:ts=4 */